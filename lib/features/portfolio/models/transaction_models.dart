/// Type of portfolio transaction.
enum TransactionType {
  deposit,
  withdraw,
  matchWin,
  matchLoss,
  matchTie,
  matchFreeze,
  matchUnfreeze,
}

/// Status of a transaction.
enum TransactionStatus { pending, confirmed, failed }

/// A single balance transaction (deposit, withdrawal, or match-related).
class Transaction {
  final String id;
  final TransactionType type;
  final double amount;
  final String address;
  final TransactionStatus status;
  final String? signature;
  final String? matchId;
  final DateTime createdAt;

  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.address,
    this.status = TransactionStatus.confirmed,
    this.signature,
    this.matchId,
    required this.createdAt,
  });

  Transaction copyWith({
    String? id,
    TransactionType? type,
    double? amount,
    String? address,
    TransactionStatus? status,
    String? signature,
    String? matchId,
    DateTime? createdAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      address: address ?? this.address,
      status: status ?? this.status,
      signature: signature ?? this.signature,
      matchId: matchId ?? this.matchId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Result of a completed match.
class MatchResult {
  final String id;
  final String opponent;
  final String duration;
  final String result; // "WIN", "LOSS", "TIE"
  final double pnl;
  final double betAmount;
  final DateTime completedAt;

  // Optional detailed stats (available for locally-completed matches).
  final int? totalTrades;
  final double? winRate;
  final double? bestTradePnl;
  final String? bestTradeAsset;
  final double? totalVolume;
  final int? hotStreak;
  final double? roi;

  const MatchResult({
    required this.id,
    required this.opponent,
    required this.duration,
    required this.result,
    required this.pnl,
    this.betAmount = 0,
    required this.completedAt,
    this.totalTrades,
    this.winRate,
    this.bestTradePnl,
    this.bestTradeAsset,
    this.totalVolume,
    this.hotStreak,
    this.roi,
  });

  bool get isWin => result == 'WIN';
  bool get isTie => result == 'TIE';
}

/// Tracks which step the deposit flow is on.
enum DepositStep { idle, signing, confirming, crediting, done }

/// State of the portfolio feature (transaction history + withdraw/deposit state).
class PortfolioState {
  final List<Transaction> transactions;
  final List<MatchResult> matchHistory;
  final bool isWithdrawing;
  final bool isDepositing;
  final DepositStep depositStep;
  final bool isLoadingHistory;
  final String? withdrawError;
  final String? depositError;

  const PortfolioState({
    this.transactions = const [],
    this.matchHistory = const [],
    this.isWithdrawing = false,
    this.isDepositing = false,
    this.depositStep = DepositStep.idle,
    this.isLoadingHistory = false,
    this.withdrawError,
    this.depositError,
  });

  PortfolioState copyWith({
    List<Transaction>? transactions,
    List<MatchResult>? matchHistory,
    bool? isWithdrawing,
    bool? isDepositing,
    DepositStep? depositStep,
    bool? isLoadingHistory,
    String? withdrawError,
    String? depositError,
    bool clearError = false,
  }) {
    return PortfolioState(
      transactions: transactions ?? this.transactions,
      matchHistory: matchHistory ?? this.matchHistory,
      isWithdrawing: isWithdrawing ?? this.isWithdrawing,
      isDepositing: isDepositing ?? this.isDepositing,
      depositStep: depositStep ?? this.depositStep,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      withdrawError: clearError ? null : (withdrawError ?? this.withdrawError),
      depositError: clearError ? null : (depositError ?? this.depositError),
    );
  }
}
