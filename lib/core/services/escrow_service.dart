import 'dart:js_interop';

import '../config/environment.dart';

@JS('_sendUsdcToEscrow')
external JSPromise _jsSendUsdcToEscrow(
  JSString walletName,
  JSString escrowAddress,
  JSNumber amountUsdc,
  JSString usdcMint,
  JSString rpcUrl,
);

/// Service for depositing USDC to the escrow wallet before a match.
class EscrowService {
  EscrowService._();

  /// Deposit [amountUsdc] USDC to the escrow wallet.
  /// The user's wallet popup will appear for approval.
  /// Returns the transaction signature on success.
  static Future<String> deposit({
    required String walletName,
    required double amountUsdc,
  }) async {
    final promise = _jsSendUsdcToEscrow(
      walletName.toJS,
      Environment.escrowWallet.toJS,
      amountUsdc.toJS,
      Environment.usdcMint.toJS,
      Environment.solanaRpcUrl.toJS,
    );

    final result = await promise.toDart;
    return (result as JSString).toDart;
  }
}
