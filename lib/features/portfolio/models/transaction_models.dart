/// Type of portfolio transaction.
enum TransactionType { deposit, withdraw }

/// Status of a transaction.
enum TransactionStatus { pending, confirmed, failed }

/// A single deposit or withdrawal transaction.
class Transaction {
  final String id;
  final TransactionType type;
  final double amount;
  final String address;
  final TransactionStatus status;
  final String? signature;
  final DateTime createdAt;

  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.address,
    this.status = TransactionStatus.pending,
    this.signature,
    required this.createdAt,
  });

  Transaction copyWith({
    String? id,
    TransactionType? type,
    double? amount,
    String? address,
    TransactionStatus? status,
    String? signature,
    DateTime? createdAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      address: address ?? this.address,
      status: status ?? this.status,
      signature: signature ?? this.signature,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Result of a completed match.
class MatchResult {
  final String id;
  final String opponent;
  final String timeframe;
  final bool isWin;
  final double pnl;
  final DateTime completedAt;

  const MatchResult({
    required this.id,
    required this.opponent,
    required this.timeframe,
    required this.isWin,
    required this.pnl,
    required this.completedAt,
  });
}

/// State of the portfolio feature (transaction history + withdraw state).
class PortfolioState {
  final List<Transaction> transactions;
  final List<MatchResult> matchHistory;
  final bool isWithdrawing;
  final bool isLoadingHistory;
  final String? withdrawError;

  const PortfolioState({
    this.transactions = const [],
    this.matchHistory = const [],
    this.isWithdrawing = false,
    this.isLoadingHistory = false,
    this.withdrawError,
  });

  PortfolioState copyWith({
    List<Transaction>? transactions,
    List<MatchResult>? matchHistory,
    bool? isWithdrawing,
    bool? isLoadingHistory,
    String? withdrawError,
    bool clearError = false,
  }) {
    return PortfolioState(
      transactions: transactions ?? this.transactions,
      matchHistory: matchHistory ?? this.matchHistory,
      isWithdrawing: isWithdrawing ?? this.isWithdrawing,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      withdrawError: clearError ? null : (withdrawError ?? this.withdrawError),
    );
  }
}
