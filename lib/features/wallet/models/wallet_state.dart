/// Connection status of the user's Solana wallet.
enum WalletConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

/// Supported wallet providers.
enum WalletType {
  phantom,
  solflare,
  backpack,
  jupiter,
}

/// Immutable state of the wallet connection.
class WalletState {
  final WalletConnectionStatus status;
  final WalletType? walletType;
  final String? address;
  final double? usdcBalance;
  final String? gamerTag;
  final String? errorMessage;

  const WalletState({
    this.status = WalletConnectionStatus.disconnected,
    this.walletType,
    this.address,
    this.usdcBalance,
    this.gamerTag,
    this.errorMessage,
  });

  bool get isConnected => status == WalletConnectionStatus.connected;
  bool get isConnecting => status == WalletConnectionStatus.connecting;
  bool get hasError => status == WalletConnectionStatus.error;

  /// Truncated address for display (e.g. "DYw8...NSKK").
  String get shortAddress {
    if (address == null || address!.length < 8) return address ?? '';
    return '${address!.substring(0, 4)}...${address!.substring(address!.length - 4)}';
  }

  WalletState copyWith({
    WalletConnectionStatus? status,
    WalletType? walletType,
    String? address,
    double? usdcBalance,
    String? gamerTag,
    String? errorMessage,
  }) {
    return WalletState(
      status: status ?? this.status,
      walletType: walletType ?? this.walletType,
      address: address ?? this.address,
      usdcBalance: usdcBalance ?? this.usdcBalance,
      gamerTag: gamerTag ?? this.gamerTag,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
