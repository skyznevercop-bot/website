import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/environment.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/solana_wallet_adapter.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../models/transaction_models.dart';

/// Manages portfolio transactions — deposit, withdraw, transaction history.
class PortfolioNotifier extends Notifier<PortfolioState> {
  final _api = ApiClient.instance;

  @override
  PortfolioState build() => const PortfolioState();

  /// Validates a Solana address (base58, 32-44 chars).
  static bool isValidSolanaAddress(String address) {
    if (address.length < 32 || address.length > 44) return false;
    final base58 = RegExp(r'^[1-9A-HJ-NP-Za-km-z]+$');
    return base58.hasMatch(address);
  }

  /// Fetch transaction history from the backend.
  Future<void> fetchTransactions() async {
    try {
      final response = await _api.get('/balance/transactions');
      final txsJson = response['transactions'] as List<dynamic>? ?? [];
      final transactions = txsJson.map((json) {
        final tx = json as Map<String, dynamic>;
        return Transaction(
          id: tx['id'] as String? ?? '',
          type: _parseTransactionType(tx['type'] as String? ?? 'deposit'),
          amount: (tx['amount'] as num).toDouble(),
          address: tx['userAddress'] as String? ?? '',
          status: TransactionStatus.confirmed,
          signature: tx['txSignature'] as String?,
          matchId: tx['matchId'] as String?,
          createdAt: tx['timestamp'] != null
              ? DateTime.fromMillisecondsSinceEpoch(tx['timestamp'] as int)
              : DateTime.now(),
        );
      }).toList();

      state = state.copyWith(transactions: transactions);
    } catch (_) {}
  }

  static TransactionType _parseTransactionType(String type) {
    switch (type) {
      case 'deposit':
        return TransactionType.deposit;
      case 'withdraw':
        return TransactionType.withdraw;
      case 'match_win':
        return TransactionType.matchWin;
      case 'match_loss':
        return TransactionType.matchLoss;
      case 'match_tie':
        return TransactionType.matchTie;
      case 'match_freeze':
        return TransactionType.matchFreeze;
      case 'match_unfreeze':
        return TransactionType.matchUnfreeze;
      default:
        return TransactionType.deposit;
    }
  }

  /// Withdraw USDC via backend platform balance API.
  Future<bool> withdraw(double amount, String destinationAddress) async {
    if (state.isWithdrawing) return false;

    final wallet = ref.read(walletProvider);
    final balance = wallet.platformBalance;

    if (amount < 1) {
      state = state.copyWith(withdrawError: 'Minimum withdrawal is 1 USDC');
      return false;
    }
    if (amount > balance) {
      state = state.copyWith(withdrawError: 'Insufficient platform balance');
      return false;
    }
    if (!isValidSolanaAddress(destinationAddress)) {
      state = state.copyWith(withdrawError: 'Invalid Solana address');
      return false;
    }

    state = state.copyWith(isWithdrawing: true, clearError: true);

    try {
      final response = await _api.post('/balance/withdraw', {
        'amount': amount,
        'destinationAddress': destinationAddress,
      });

      final sig = response['txSignature'] as String?;
      final tx = Transaction(
        id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
        type: TransactionType.withdraw,
        amount: amount,
        address: destinationAddress,
        status: TransactionStatus.confirmed,
        signature: sig,
        createdAt: DateTime.now(),
      );

      // Refresh platform balance from backend.
      ref.read(walletProvider.notifier).refreshPlatformBalance();

      state = state.copyWith(
        isWithdrawing: false,
        transactions: [tx, ...state.transactions],
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        isWithdrawing: false,
        withdrawError: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isWithdrawing: false,
        withdrawError: 'Withdrawal failed: ${e.toString()}',
      );
      return false;
    }
  }

  /// One-click deposit: sign + send USDC transfer via wallet, then poll backend.
  Future<bool> deposit(double amount) async {
    if (state.isDepositing) return false;

    final wallet = ref.read(walletProvider);
    if (wallet.address == null || wallet.walletType == null) {
      state = state.copyWith(depositError: 'Wallet not connected');
      return false;
    }
    if (amount < 1) {
      state = state.copyWith(depositError: 'Minimum deposit is 1 USDC');
      return false;
    }
    if (amount > (wallet.usdcBalance ?? 0)) {
      state = state.copyWith(depositError: 'Insufficient USDC in wallet');
      return false;
    }

    // ── Step 1: Signing ──
    state = state.copyWith(
      isDepositing: true,
      depositStep: DepositStep.signing,
      clearError: true,
    );

    try {
      final vaultAddress = await getVaultAddress();
      if (vaultAddress == null) {
        state = state.copyWith(
          isDepositing: false,
          depositStep: DepositStep.idle,
          depositError: 'Could not load vault address',
        );
        return false;
      }

      // Wallet popup appears here.
      final signature = await SolanaWalletAdapter.depositToVault(
        walletName: wallet.walletType!.name,
        vaultAddress: vaultAddress,
        amount: amount,
        usdcMint: Environment.usdcMint,
        rpcUrl: Environment.solanaRpcUrl,
      );

      // ── Step 2: Confirming on-chain ──
      state = state.copyWith(depositStep: DepositStep.confirming);

      // Poll backend — the RPC may not see the tx immediately.
      bool confirmed = false;
      String? lastError;
      for (int attempt = 0; attempt < 15; attempt++) {
        if (attempt > 0) {
          await Future.delayed(const Duration(seconds: 3));
        }
        try {
          await _api.post('/balance/deposit', {'txSignature': signature});
          confirmed = true;
          break;
        } on ApiException catch (e) {
          lastError = e.message;
          // Stop on definitive errors (replay, wrong sender, etc.).
          if (!_isRetryableDepositError(e.message)) break;
        } catch (e) {
          lastError = e.toString();
        }
      }

      if (!confirmed) {
        state = state.copyWith(
          isDepositing: false,
          depositStep: DepositStep.idle,
          depositError: lastError ?? 'Transaction not confirmed on-chain',
        );
        return false;
      }

      // ── Step 3: Crediting balance ──
      state = state.copyWith(depositStep: DepositStep.crediting);
      ref.read(walletProvider.notifier).refreshPlatformBalance();
      ref.read(walletProvider.notifier).refreshBalance();
      await fetchTransactions();

      state = state.copyWith(
        isDepositing: false,
        depositStep: DepositStep.done,
      );
      return true;
    } on WalletException catch (e) {
      state = state.copyWith(
        isDepositing: false,
        depositStep: DepositStep.idle,
        depositError: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isDepositing: false,
        depositStep: DepositStep.idle,
        depositError: 'Deposit failed: ${e.toString()}',
      );
      return false;
    }
  }

  /// Returns true if the backend error is transient (tx not yet visible).
  static bool _isRetryableDepositError(String msg) {
    final lower = msg.toLowerCase();
    return lower.contains('not found') ||
        lower.contains('not yet') ||
        lower.contains('not confirmed');
  }

  /// Confirm a deposit with the backend (after on-chain USDC transfer to vault).
  Future<bool> confirmDeposit(String txSignature) async {
    state = state.copyWith(isDepositing: true, clearError: true);
    try {
      await _api.post('/balance/deposit', {
        'txSignature': txSignature,
      });

      // Refresh platform balance from backend.
      ref.read(walletProvider.notifier).refreshPlatformBalance();

      state = state.copyWith(isDepositing: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        isDepositing: false,
        depositError: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isDepositing: false,
        depositError: 'Deposit confirmation failed: ${e.toString()}',
      );
      return false;
    }
  }

  /// Get the platform vault address for deposits.
  Future<String?> getVaultAddress() async {
    try {
      final response = await _api.get('/balance/vault');
      return response['vaultAddress'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Fetch completed match history from the backend.
  Future<void> fetchMatchHistory() async {
    final wallet = ref.read(walletProvider);
    if (wallet.address == null) return;

    state = state.copyWith(isLoadingHistory: true);
    try {
      final response = await _api.get('/match/history/${wallet.address}');
      final matchesJson = response['matches'] as List<dynamic>? ?? [];
      final matches = matchesJson.map((json) {
        final m = json as Map<String, dynamic>;
        return MatchResult(
          id: m['id'] as String? ?? '',
          opponent: m['opponentGamerTag'] as String? ?? 'Unknown',
          duration: m['duration'] as String? ?? '',
          result: m['result'] as String? ?? 'LOSS',
          pnl: (m['pnl'] as num?)?.toDouble() ?? 0,
          betAmount: (m['betAmount'] as num?)?.toDouble() ?? 0,
          completedAt: m['settledAt'] != null
              ? DateTime.fromMillisecondsSinceEpoch(m['settledAt'] as int)
              : DateTime.now(),
        );
      }).toList();

      state = state.copyWith(matchHistory: matches, isLoadingHistory: false);
    } catch (_) {
      // Backend unavailable — keep existing state.
      state = state.copyWith(isLoadingHistory: false);
    }
  }

  /// Add a locally-completed match result to the history.
  void addMatchResult(MatchResult result) {
    // Avoid duplicates (same matchId).
    final existing = state.matchHistory.any((m) => m.id == result.id);
    if (existing) return;

    state = state.copyWith(
      matchHistory: [result, ...state.matchHistory],
    );
  }

  /// Check if the connected wallet is admin and fetch rake stats if so.
  Future<void> checkAdminStatus() async {
    try {
      final response = await _api.get('/balance/admin/check');
      final isAdmin = response['isAdmin'] as bool? ?? false;
      state = state.copyWith(isAdmin: isAdmin);
      if (isAdmin) await fetchRakeStats();
    } catch (_) {
      state = state.copyWith(isAdmin: false);
    }
  }

  /// Fetch platform rake stats (admin only).
  Future<void> fetchRakeStats() async {
    try {
      final response = await _api.get('/balance/admin/stats');
      state = state.copyWith(
        accumulatedRake: (response['accumulatedRake'] as num?)?.toDouble() ?? 0,
        totalRakeCollected: (response['totalRakeCollected'] as num?)?.toDouble() ?? 0,
      );
    } catch (_) {}
  }

  /// Withdraw accumulated rake to admin wallet (admin only).
  Future<bool> withdrawRake() async {
    if (state.isWithdrawingRake) return false;
    state = state.copyWith(isWithdrawingRake: true, clearError: true);
    try {
      final response = await _api.post('/balance/admin/withdraw-rake', {});
      final sig = response['txSignature'] as String?;
      state = state.copyWith(
        isWithdrawingRake: false,
        accumulatedRake: 0,
        rakeWithdrawTxSignature: sig,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        isWithdrawingRake: false,
        rakeWithdrawError: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isWithdrawingRake: false,
        rakeWithdrawError: 'Withdrawal failed: ${e.toString()}',
      );
      return false;
    }
  }

  /// Reset all portfolio state (used when switching wallets).
  void reset() {
    state = const PortfolioState();
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final portfolioProvider =
    NotifierProvider<PortfolioNotifier, PortfolioState>(PortfolioNotifier.new);
