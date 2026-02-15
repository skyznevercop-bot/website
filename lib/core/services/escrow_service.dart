import 'dart:js_interop';

import '../config/environment.dart';

@JS('_depositToEscrow')
external JSPromise _jsDepositToEscrow(
  JSString walletName,
  JSString programId,
  JSString gamePda,
  JSString escrowTokenAccount,
  JSString usdcMint,
  JSString rpcUrl,
);

@JS('_claimWinnings')
external JSPromise _jsClaimWinnings(
  JSString walletName,
  JSString programId,
  JSString gamePda,
  JSString escrowTokenAccount,
  JSString platformPda,
  JSString treasuryAddress,
  JSString usdcMint,
  JSString rpcUrl,
);

@JS('_createProfile')
external JSPromise _jsCreateProfile(
  JSString walletName,
  JSString programId,
  JSString profilePda,
  JSString gamerTag,
  JSString rpcUrl,
);

/// Service for interacting with the on-chain SolFight escrow program.
class EscrowService {
  EscrowService._();

  /// Deposit the bet amount to the game's on-chain escrow.
  /// Calls the program's deposit_to_escrow instruction — the user's wallet
  /// popup will appear for approval.
  /// Returns the transaction signature on success.
  static Future<String> deposit({
    required String walletName,
    required String gamePda,
    required String escrowTokenAccount,
  }) async {
    final promise = _jsDepositToEscrow(
      walletName.toJS,
      Environment.programId.toJS,
      gamePda.toJS,
      escrowTokenAccount.toJS,
      Environment.usdcMint.toJS,
      Environment.solanaRpcUrl.toJS,
    );

    final result = await promise.toDart;
    return (result as JSString).toDart;
  }

  /// Claim winnings from a settled/forfeited game.
  /// Calls the program's claim_winnings instruction — the winner's wallet
  /// popup will appear for approval.
  /// Returns the transaction signature on success.
  static Future<String> claimWinnings({
    required String walletName,
    required String gamePda,
    required String escrowTokenAccount,
    required String platformPda,
    required String treasuryAddress,
  }) async {
    final promise = _jsClaimWinnings(
      walletName.toJS,
      Environment.programId.toJS,
      gamePda.toJS,
      escrowTokenAccount.toJS,
      platformPda.toJS,
      treasuryAddress.toJS,
      Environment.usdcMint.toJS,
      Environment.solanaRpcUrl.toJS,
    );

    final result = await promise.toDart;
    return (result as JSString).toDart;
  }

  /// Create an on-chain player profile.
  /// Required before a game can be settled on-chain (end_game needs profiles).
  /// Returns the transaction signature on success.
  static Future<String> createProfile({
    required String walletName,
    required String profilePda,
    required String gamerTag,
  }) async {
    final promise = _jsCreateProfile(
      walletName.toJS,
      Environment.programId.toJS,
      profilePda.toJS,
      gamerTag.toJS,
      Environment.solanaRpcUrl.toJS,
    );

    final result = await promise.toDart;
    return (result as JSString).toDart;
  }
}
