import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

/// Result of connecting to a wallet.
class WalletConnectionResult {
  final String publicKey;
  WalletConnectionResult(this.publicKey);
}

/// Adapter for connecting to Solana wallets via browser extension JS interop.
class SolanaWalletAdapter {
  SolanaWalletAdapter._();

  /// Check if a wallet extension is installed.
  static bool isWalletInstalled(String walletName) {
    try {
      switch (walletName.toLowerCase()) {
        case 'phantom':
          final phantom =
              globalContext.getProperty('phantom'.toJS) as JSObject?;
          if (phantom == null) return false;
          final solana = phantom.getProperty('solana'.toJS);
          return solana != null && solana.isA<JSObject>();
        case 'solflare':
          final solflare = globalContext.getProperty('solflare'.toJS);
          return solflare != null && solflare.isA<JSObject>();
        case 'backpack':
          final backpack = globalContext.getProperty('backpack'.toJS);
          return backpack != null && backpack.isA<JSObject>();
        default:
          return false;
      }
    } catch (_) {
      return false;
    }
  }

  /// Get the wallet provider object for the given wallet name.
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
          final backpack = globalContext.getProperty('backpack'.toJS);
          return backpack.isA<JSObject>() ? backpack as JSObject : null;
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  /// Connect to a wallet. Returns the public key string on success.
  static Future<WalletConnectionResult> connect(String walletName) async {
    final provider = _getProvider(walletName);
    if (provider == null) {
      throw WalletException('$walletName wallet not found');
    }

    final connectResult =
        provider.callMethod('connect'.toJS) as JSPromise;
    final result = (await connectResult.toDart) as JSObject;

    final publicKey = result.getProperty('publicKey'.toJS) as JSObject;
    final base58 =
        publicKey.callMethod('toString'.toJS) as JSString;

    return WalletConnectionResult(base58.toDart);
  }

  /// Disconnect the wallet.
  static Future<void> disconnect(String walletName) async {
    final provider = _getProvider(walletName);
    if (provider == null) return;

    try {
      final disconnectResult =
          provider.callMethod('disconnect'.toJS) as JSPromise;
      await disconnectResult.toDart;
    } catch (_) {
      // Some wallets don't support disconnect — ignore.
    }
  }

  /// Sign a message with the wallet (for authentication).
  /// Returns the signature as a Uint8List.
  static Future<Uint8List> signMessage(
    String walletName,
    Uint8List message,
  ) async {
    final provider = _getProvider(walletName);
    if (provider == null) {
      throw WalletException('$walletName wallet not found');
    }

    final jsMessage = message.toJS;

    final signResult = provider.callMethod(
        'signMessage'.toJS, jsMessage, 'utf8'.toJS) as JSPromise;
    final result = (await signResult.toDart) as JSObject;

    final signature =
        result.getProperty('signature'.toJS) as JSUint8Array;

    return signature.toDart;
  }

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

  /// Get all detected wallet names.
  static List<String> getDetectedWallets() {
    final wallets = <String>[];
    if (isWalletInstalled('phantom')) wallets.add('Phantom');
    if (isWalletInstalled('solflare')) wallets.add('Solflare');
    if (isWalletInstalled('backpack')) wallets.add('Backpack');
    return wallets;
  }
}

class WalletException implements Exception {
  final String message;
  WalletException(this.message);

  @override
  String toString() => 'WalletException: $message';
}
