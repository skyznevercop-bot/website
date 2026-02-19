import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

/// Result of connecting to a wallet.
class WalletConnectionResult {
  final String publicKey;
  WalletConnectionResult(this.publicKey);
}

/// Adapter for connecting to Solana wallets via browser extension JS interop.
///
/// Supports two connection modes:
/// - **Legacy providers**: Phantom, Solflare, Backpack inject globals like
///   `window.phantom.solana`, `window.solflare`, `window.backpack`.
/// - **Wallet Standard**: Jupiter (and other modern wallets) register via the
///   Wallet Standard protocol. A JS bridge in index.html exposes them through
///   `window._walletStandard`.
class SolanaWalletAdapter {
  SolanaWalletAdapter._();

  // ── Detection ─────────────────────────────────────────────

  /// Check if a wallet extension is installed.
  static bool isWalletInstalled(String walletName) {
    try {
      if (_getProvider(walletName) != null) return true;
      // Fallback: check Wallet Standard registry.
      return _isWalletStandardAvailable(walletName);
    } catch (_) {
      return false;
    }
  }

  /// Get all detected wallet names.
  static List<String> getDetectedWallets() {
    final wallets = <String>[];
    if (isWalletInstalled('phantom')) wallets.add('Phantom');
    if (isWalletInstalled('solflare')) wallets.add('Solflare');
    if (isWalletInstalled('backpack')) wallets.add('Backpack');
    if (isWalletInstalled('jupiter')) wallets.add('Jupiter');
    return wallets;
  }

  // ── Legacy provider lookup ────────────────────────────────

  /// Get the legacy wallet provider object for the given wallet name.
  static JSObject? _getProvider(String walletName) {
    try {
      switch (walletName.toLowerCase()) {
        case 'phantom':
          final phantom =
              globalContext.getProperty('phantom'.toJS) as JSObject?;
          if (phantom == null) return null;
          final solana = phantom.getProperty('solana'.toJS);
          return solana.isA<JSObject>() ? solana as JSObject : null;
        case 'solflare':
          final solflare = globalContext.getProperty('solflare'.toJS);
          return solflare.isA<JSObject>() ? solflare as JSObject : null;
        case 'backpack':
          final xnft = globalContext.getProperty('xnft'.toJS);
          if (xnft != null && xnft.isA<JSObject>()) {
            final solana = (xnft as JSObject).getProperty('solana'.toJS);
            if (solana != null && solana.isA<JSObject>()) {
              return solana as JSObject;
            }
          }
          final backpack = globalContext.getProperty('backpack'.toJS);
          return backpack != null && backpack.isA<JSObject>()
              ? backpack as JSObject
              : null;
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  // ── Wallet Standard helpers ───────────────────────────────

  static JSObject? get _walletStandardBridge {
    final ws = globalContext.getProperty('_walletStandard'.toJS);
    return ws != null && ws.isA<JSObject>() ? ws as JSObject : null;
  }

  static bool _isWalletStandardAvailable(String walletName) {
    try {
      final bridge = _walletStandardBridge;
      if (bridge == null) return false;
      final wallet = bridge.callMethod('getByName'.toJS, walletName.toJS);
      return wallet != null && wallet.isA<JSObject>();
    } catch (_) {
      return false;
    }
  }

  // ── Connect ───────────────────────────────────────────────

  /// Connect to a wallet. Returns the public key string on success.
  static Future<WalletConnectionResult> connect(String walletName) async {
    // Try legacy provider first (Phantom, Solflare, Backpack).
    final provider = _getProvider(walletName);
    if (provider != null) {
      return _connectLegacy(provider, walletName);
    }

    // Fall back to Wallet Standard (Jupiter and others).
    // Always attempt for wallets without a legacy provider — the JS bridge
    // has a built-in retry loop that waits for late-loading extensions.
    if (_walletStandardBridge != null) {
      return _connectWalletStandard(walletName);
    }

    throw WalletException(
        '$walletName wallet not found. Please install the $walletName browser extension.');
  }

  /// Eagerly reconnect to a wallet that was previously approved.
  /// Uses `{ onlyIfTrusted: true }` so no popup is shown — the call
  /// silently succeeds if the user previously approved this dapp,
  /// or throws if not trusted / extension not installed.
  static Future<WalletConnectionResult> connectEagerly(
      String walletName) async {
    final provider = _getProvider(walletName);
    if (provider != null) {
      return _connectLegacy(provider, walletName, onlyIfTrusted: true);
    }

    // Wallet Standard — try normal connect; most adapters remember approval.
    if (_walletStandardBridge != null) {
      return _connectWalletStandard(walletName);
    }

    throw WalletException('$walletName wallet not available for reconnection.');
  }

  /// Connect via a legacy injected provider.
  static Future<WalletConnectionResult> _connectLegacy(
      JSObject provider, String walletName,
      {bool onlyIfTrusted = false}) async {
    final JSPromise connectResult;
    if (onlyIfTrusted) {
      // Pass { onlyIfTrusted: true } — Phantom / Solflare will auto-approve
      // if the user previously connected, or reject without showing a popup.
      final options = JSObject();
      options.setProperty('onlyIfTrusted'.toJS, true.toJS);
      connectResult =
          provider.callMethod('connect'.toJS, options) as JSPromise;
    } else {
      connectResult =
          provider.callMethod('connect'.toJS) as JSPromise;
    }
    final result = await connectResult.toDart;

    // Some wallets (Phantom) return { publicKey } from connect().
    // Others (Solflare) resolve to a boolean and expose publicKey on the
    // provider object instead. Handle both cases.
    JSObject publicKey;
    if (result.isA<JSObject>()) {
      final pk = (result as JSObject).getProperty('publicKey'.toJS);
      if (pk != null && pk.isA<JSObject>()) {
        publicKey = pk as JSObject;
      } else {
        final providerPk = provider.getProperty('publicKey'.toJS);
        if (providerPk != null && providerPk.isA<JSObject>()) {
          publicKey = providerPk as JSObject;
        } else {
          throw WalletException('Failed to get public key from $walletName');
        }
      }
    } else {
      final providerPk = provider.getProperty('publicKey'.toJS);
      if (providerPk != null && providerPk.isA<JSObject>()) {
        publicKey = providerPk as JSObject;
      } else {
        throw WalletException('Failed to get public key from $walletName');
      }
    }

    final base58 = publicKey.callMethod('toString'.toJS) as JSString;
    return WalletConnectionResult(base58.toDart);
  }

  /// Connect via the Wallet Standard JS bridge.
  static Future<WalletConnectionResult> _connectWalletStandard(
      String walletName) async {
    final bridge = _walletStandardBridge!;
    final promise =
        bridge.callMethod('connect'.toJS, walletName.toJS) as JSPromise;
    final result = (await promise.toDart) as JSObject;

    final pk = result.getProperty('publicKey'.toJS) as JSString;
    return WalletConnectionResult(pk.toDart);
  }

  // ── Disconnect ────────────────────────────────────────────

  /// Disconnect the wallet.
  static Future<void> disconnect(String walletName) async {
    // Legacy provider.
    final provider = _getProvider(walletName);
    if (provider != null) {
      try {
        final disconnectResult =
            provider.callMethod('disconnect'.toJS) as JSPromise;
        await disconnectResult.toDart;
      } catch (_) {}
      return;
    }

    // Wallet Standard.
    final bridge = _walletStandardBridge;
    if (bridge != null) {
      try {
        final promise =
            bridge.callMethod('disconnect'.toJS, walletName.toJS) as JSPromise;
        await promise.toDart;
      } catch (_) {}
    }
  }

  // ── Sign Message ──────────────────────────────────────────

  /// Sign a message with the wallet (for authentication).
  /// Returns the signature as a Uint8List.
  static Future<Uint8List> signMessage(
    String walletName,
    Uint8List message,
  ) async {
    // Legacy provider.
    final provider = _getProvider(walletName);
    if (provider != null) {
      final jsMessage = message.toJS;
      final signResult = provider.callMethod(
          'signMessage'.toJS, jsMessage, 'utf8'.toJS) as JSPromise;
      final result = (await signResult.toDart) as JSObject;
      final signature =
          result.getProperty('signature'.toJS) as JSUint8Array;
      return signature.toDart;
    }

    // Wallet Standard.
    final bridge = _walletStandardBridge;
    if (bridge != null && _isWalletStandardAvailable(walletName)) {
      final promise = bridge.callMethod(
          'signMessage'.toJS, walletName.toJS, message.toJS) as JSPromise;
      final result = (await promise.toDart) as JSObject;
      final signature =
          result.getProperty('signature'.toJS) as JSUint8Array;
      return signature.toDart;
    }

    throw WalletException('$walletName wallet not found');
  }

  // ── Sign & Send Transaction ───────────────────────────────

  /// Sign and send a transaction.
  /// [transactionBytes] is the serialized transaction.
  /// Returns the transaction signature string.
  static Future<String> signAndSendTransaction(
    String walletName,
    Uint8List transactionBytes,
  ) async {
    final provider = _getProvider(walletName);
    if (provider == null) {
      throw WalletException('$walletName wallet not found');
    }

    final solanaWeb3 =
        globalContext.getProperty('solanaWeb3'.toJS) as JSObject?;
    if (solanaWeb3 == null) {
      throw WalletException('Solana Web3 JS library not loaded');
    }

    final transactionClass =
        solanaWeb3.getProperty('Transaction'.toJS) as JSFunction;
    final transaction = transactionClass.callAsConstructor(
        transactionBytes.toJS) as JSObject;

    final signResult = provider.callMethod(
        'signAndSendTransaction'.toJS, transaction) as JSPromise;
    final result = (await signResult.toDart) as JSObject;

    final signature =
        result.getProperty('signature'.toJS) as JSString;

    return signature.toDart;
  }

  // ── Deposit USDC to vault ────────────────────────────────

  /// Build, sign, and send a USDC transfer to the platform vault.
  /// Returns the transaction signature on success.
  static Future<String> depositToVault({
    required String walletName,
    required String vaultAddress,
    required double amount,
    required String usdcMint,
    required String rpcUrl,
  }) async {
    final promise = globalContext.callMethodVarArgs(
      '_depositToVault'.toJS,
      [
        walletName.toJS,
        vaultAddress.toJS,
        amount.toJS,
        usdcMint.toJS,
        rpcUrl.toJS,
      ],
    ) as JSPromise;

    final result = await promise.toDart;
    if (result == null) {
      throw WalletException('Deposit returned no signature');
    }
    return (result as JSString).toDart;
  }
}

class WalletException implements Exception {
  final String message;
  WalletException(this.message);

  @override
  String toString() => 'WalletException: $message';
}
