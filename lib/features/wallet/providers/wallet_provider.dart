import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';
import '../../../core/services/solana_wallet_adapter.dart';
import '../models/wallet_state.dart';

/// Manages wallet connection lifecycle with real Solana wallet extensions
/// and backend JWT authentication.
class WalletNotifier extends Notifier<WalletState> {
  @override
  WalletState build() => const WalletState();

  final _api = ApiClient.instance;

  /// Connect to a wallet provider via JS interop.
  /// Attempts backend auth (JWT) if available; falls back to wallet-only mode.
  Future<void> connect(WalletType type) async {
    state = state.copyWith(
      status: WalletConnectionStatus.connecting,
      walletType: type,
      errorMessage: null,
    );

    try {
      final walletName = type.name; // 'phantom', 'solflare', 'backpack', 'jupiter'

      // 1. Connect to the wallet extension.
      final result = await SolanaWalletAdapter.connect(walletName);
      final address = result.publicKey;

      // 2. Try backend auth — gracefully fall back if backend is unreachable.
      String? gamerTag;
      double balance = 0;
      bool backendAvailable = false;

      try {
        // Get nonce from backend.
        final nonceResponse =
            await _api.get('/auth/nonce?address=$address');
        final nonce = nonceResponse['nonce'] as String;
        final message = nonceResponse['message'] as String;

        // Sign the nonce with the wallet.
        final messageBytes = Uint8List.fromList(utf8.encode(message));
        final signatureBytes =
            await SolanaWalletAdapter.signMessage(walletName, messageBytes);

        // Base58 encode the signature for the backend.
        final signatureBase58 = _base58Encode(signatureBytes);

        // Verify with backend and get JWT.
        final authResponse = await _api.post('/auth/verify', {
          'address': address,
          'signature': signatureBase58,
          'nonce': nonce,
        });

        final token = authResponse['token'] as String;
        await _api.setToken(token);

        // Connect WebSocket with the JWT.
        _api.connectWebSocket();

        // Fetch user profile from backend.
        final userResponse = await _api.get('/user/$address');
        gamerTag = userResponse['gamerTag'] as String?;

        // Fetch balance.
        final balanceResponse = await _api.get('/portfolio/balance');
        balance =
            (balanceResponse['platformBalance'] as num).toDouble();

        backendAvailable = true;
      } catch (_) {
        // Backend unreachable — wallet-only mode.
        backendAvailable = false;
      }

      _backendConnected = backendAvailable;

      // Fetch on-chain USDC balance when backend is not available.
      if (!backendAvailable) {
        balance = await _fetchOnChainUsdcBalance(address);
      }

      state = state.copyWith(
        status: WalletConnectionStatus.connected,
        address: address,
        usdcBalance: balance,
        gamerTag: gamerTag,
      );
    } on WalletException catch (e) {
      state = state.copyWith(
        status: WalletConnectionStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        status: WalletConnectionStatus.error,
        errorMessage: 'Failed to connect: ${e.toString()}',
      );
    }
  }

  /// Whether the backend was reachable during the last connection.
  bool _backendConnected = false;
  bool get isBackendConnected => _backendConnected;

  /// Disconnect the current wallet.
  Future<void> disconnect() async {
    final walletName = state.walletType?.name;
    if (walletName != null) {
      await SolanaWalletAdapter.disconnect(walletName);
    }
    _api.disconnectWebSocket();
    await _api.clearToken();
    state = const WalletState();
  }

  /// Set the user's gamer tag (persisted to backend if available).
  Future<void> setGamerTag(String tag) async {
    if (!_backendConnected) {
      // Wallet-only mode: store locally only.
      state = state.copyWith(gamerTag: tag);
      return;
    }
    try {
      await _api.put('/user/gamer-tag', {'gamerTag': tag});
      state = state.copyWith(gamerTag: tag);
    } on ApiException catch (e) {
      // Tag might be taken — surface error but keep existing state.
      state = state.copyWith(errorMessage: e.message);
    }
  }

  /// Deduct USDC from the local balance (optimistic update after bet).
  void deductBalance(double amount) {
    final current = state.usdcBalance ?? 0;
    state = state.copyWith(
        usdcBalance: (current - amount).clamp(0, double.infinity));
  }

  /// Add USDC to the local balance (after reward, etc.).
  void addBalance(double amount) {
    final current = state.usdcBalance ?? 0;
    state = state.copyWith(usdcBalance: current + amount);
  }

  /// Refresh USDC balance from the backend or on-chain.
  Future<void> refreshBalance() async {
    if (!state.isConnected || state.address == null) return;
    try {
      if (_backendConnected) {
        final response = await _api.get('/portfolio/balance');
        final platformBalance =
            (response['platformBalance'] as num).toDouble();
        state = state.copyWith(usdcBalance: platformBalance);
      } else {
        final balance = await _fetchOnChainUsdcBalance(state.address!);
        state = state.copyWith(usdcBalance: balance);
      }
    } catch (_) {
      // Silently fail, keep existing balance.
    }
  }

  /// Fetch USDC balance from Solana mainnet via JS interop (browser fetch).
  static Future<double> _fetchOnChainUsdcBalance(String walletAddress) async {
    try {
      final fn = globalContext.getProperty('_getUsdcBalance'.toJS);
      if (fn == null || !fn.isA<JSFunction>()) return 0;

      final promise = globalContext.callMethod(
          '_getUsdcBalance'.toJS, walletAddress.toJS) as JSPromise;
      final result = await promise.toDart;

      if (result.isA<JSNumber>()) {
        return (result as JSNumber).toDartDouble;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// Simple Base58 encoder (Bitcoin-style).
  static String _base58Encode(Uint8List bytes) {
    const alphabet =
        '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    var bigInt = BigInt.zero;
    for (final byte in bytes) {
      bigInt = bigInt * BigInt.from(256) + BigInt.from(byte);
    }
    final result = StringBuffer();
    while (bigInt > BigInt.zero) {
      final remainder = (bigInt % BigInt.from(58)).toInt();
      bigInt = bigInt ~/ BigInt.from(58);
      result.write(alphabet[remainder]);
    }
    // Add leading '1's for leading zero bytes.
    for (final byte in bytes) {
      if (byte == 0) {
        result.write('1');
      } else {
        break;
      }
    }
    return result.toString().split('').reversed.join();
  }
}

final walletProvider =
    NotifierProvider<WalletNotifier, WalletState>(WalletNotifier.new);
