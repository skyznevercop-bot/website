/// Environment configuration for SolFight.
/// Toggle [useDevnet] to switch between devnet and mainnet.
class Environment {
  Environment._();

  static const bool useDevnet = true;

  // ── Backend ─────────────────────────────────────────────
  static const String apiBaseUrl = useDevnet
      ? 'http://localhost:3000/api'
      : 'https://api.solfight.io/api';

  static const String wsUrl = useDevnet
      ? 'ws://localhost:3000/ws'
      : 'wss://api.solfight.io/ws';

  // ── Solana ──────────────────────────────────────────────
  static const String solanaRpcUrl = useDevnet
      ? 'https://api.devnet.solana.com'
      : 'https://api.mainnet-beta.solana.com';

  static const String programId =
      'So1F1gHTxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';

  /// USDC SPL token mint address.
  static const String usdcMint = useDevnet
      ? '4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU' // devnet USDC
      : 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v'; // mainnet USDC

  // ── SharedPreferences Keys ──────────────────────────────
  static const String jwtTokenKey = 'solfight_jwt_token';
  static const String walletAddressKey = 'solfight_wallet_address';
}
