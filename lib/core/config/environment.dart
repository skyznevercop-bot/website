/// Environment configuration for SolFight.
/// Toggle [useDevnet] to switch between devnet and mainnet.
class Environment {
  Environment._();

  static const bool useDevnet = false;

  // ── Backend (Render hosts both devnet and mainnet for now) ──
  static const String apiBaseUrl =
      'https://solfight-backend.onrender.com/api';

  static const String wsUrl =
      'wss://solfight-backend.onrender.com/ws';

  // ── Solana ──────────────────────────────────────────────
  /// Primary RPC — PublicNode (free, CORS-friendly).
  static const String solanaRpcUrl = useDevnet
      ? 'https://api.devnet.solana.com'
      : 'https://solana-rpc.publicnode.com';

  /// Fallback RPC — our own backend proxy (server-side, no CORS issues).
  static const String solanaRpcUrlFallback = useDevnet
      ? 'https://api.devnet.solana.com'
      : '$apiBaseUrl/rpc-proxy';

  static const String programId =
      'So1F1gHTxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';

  /// USDC SPL token mint address.
  static const String usdcMint = useDevnet
      ? '4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU' // devnet USDC
      : 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v'; // mainnet USDC

  /// Treasury/escrow wallet for match bet deposits.
  static const String escrowWallet = useDevnet
      ? '6ofVTNgoHbJGBtQB3xCDYXNayc8vczXu2Vob4bDBZtVc'
      : '6ofVTNgoHbJGBtQB3xCDYXNayc8vczXu2Vob4bDBZtVc';

  // ── SharedPreferences Keys ──────────────────────────────
  static const String jwtTokenKey = 'solfight_jwt_token';
  static const String walletAddressKey = 'solfight_wallet_address';
}
