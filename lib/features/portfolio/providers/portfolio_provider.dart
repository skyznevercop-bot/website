import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
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

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final portfolioProvider =
    NotifierProvider<PortfolioNotifier, PortfolioState>(PortfolioNotifier.new);
