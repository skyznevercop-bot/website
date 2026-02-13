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
      final response = await _api.get('/portfolio/transactions');
      final txsJson = response['transactions'] as List<dynamic>;
      final transactions = txsJson.map((json) {
        final tx = json as Map<String, dynamic>;
        return Transaction(
          id: tx['id'] as String,
          type: tx['type'] == 'DEPOSIT'
              ? TransactionType.deposit
              : TransactionType.withdraw,
          amount: (tx['amount'] as num).toDouble(),
          address: tx['userAddress'] as String,
          status: _parseStatus(tx['status'] as String),
          signature: tx['signature'] as String?,
          createdAt: DateTime.parse(tx['createdAt'] as String),
        );
      }).toList();

      state = state.copyWith(transactions: transactions);
    } catch (_) {}
  }

  static TransactionStatus _parseStatus(String status) {
    switch (status) {
      case 'CONFIRMED':
        return TransactionStatus.confirmed;
      case 'FAILED':
        return TransactionStatus.failed;
      default:
        return TransactionStatus.pending;
    }
  }

  /// Withdraw USDC via backend API.
  Future<bool> withdraw(double amount, String destinationAddress) async {
    if (state.isWithdrawing) return false;

    final wallet = ref.read(walletProvider);
    final balance = wallet.usdcBalance ?? 0;

    if (amount < 1) {
      state = state.copyWith(withdrawError: 'Minimum withdrawal is 1 USDC');
      return false;
    }
    if (amount > balance) {
      state = state.copyWith(withdrawError: 'Insufficient balance');
      return false;
    }
    if (!isValidSolanaAddress(destinationAddress)) {
      state = state.copyWith(withdrawError: 'Invalid Solana address');
      return false;
    }

    state = state.copyWith(isWithdrawing: true, clearError: true);

    try {
      final response = await _api.post('/portfolio/withdraw', {
        'amount': amount,
        'destinationAddress': destinationAddress,
      });

      final tx = Transaction(
        id: response['transactionId'] as String,
        type: TransactionType.withdraw,
        amount: amount,
        address: destinationAddress,
        status: TransactionStatus.confirmed,
        createdAt: DateTime.now(),
      );

      ref.read(walletProvider.notifier).deductBalance(amount);

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

  /// Notify backend of a deposit (after on-chain transfer).
  Future<void> notifyDeposit(double amount, String signature) async {
    try {
      await _api.post('/portfolio/deposit', {
        'amount': amount,
        'signature': signature,
      });

      final tx = Transaction(
        id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
        type: TransactionType.deposit,
        amount: amount,
        address: '',
        status: TransactionStatus.pending,
        signature: signature,
        createdAt: DateTime.now(),
      );
      state = state.copyWith(transactions: [tx, ...state.transactions]);
    } catch (_) {}
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final portfolioProvider =
    NotifierProvider<PortfolioNotifier, PortfolioState>(PortfolioNotifier.new);
