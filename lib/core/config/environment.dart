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
  /// Primary RPC — Helius (dedicated, reliable).
  static const String solanaRpcUrl = useDevnet
      ? 'https://api.devnet.solana.com'
      : 'https://mainnet.helius-rpc.com/?api-key=3ed6e181-117d-475f-9e54-2cd48e3f19a0';

  /// Fallback RPC — our own backend proxy (server-side, no CORS issues).
  static const String solanaRpcUrlFallback = useDevnet
      ? 'https://api.devnet.solana.com'
      : '$apiBaseUrl/rpc-proxy';

  /// Tertiary RPC — official Solana mainnet.
  static const String solanaRpcUrl2 = useDevnet
      ? 'https://api.devnet.solana.com'
      : 'https://api.mainnet-beta.solana.com';

  static const String programId =
      '268xoH5VPMgtcuaBgXimyRHebsubszqQzPUrU5duJLL8';

  /// USDC SPL token mint address.
  static const String usdcMint = useDevnet
      ? '4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU' // devnet USDC
      : 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v'; // mainnet USDC

  // ── SharedPreferences Keys ──────────────────────────────
  static const String jwtTokenKey = 'solfight_jwt_token';
  static const String walletAddressKey = 'solfight_wallet_address';
}
