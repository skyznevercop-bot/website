import 'dart:convert';
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

  /// Connect to a wallet provider via JS interop + authenticate with backend.
  Future<void> connect(WalletType type) async {
    state = state.copyWith(
      status: WalletConnectionStatus.connecting,
      walletType: type,
      errorMessage: null,
    );

    try {
      final walletName = type.name; // 'phantom', 'solflare', 'backpack'

      // 1. Connect to the wallet extension.
      final result = await SolanaWalletAdapter.connect(walletName);
      final address = result.publicKey;

      // 2. Get nonce from backend.
      final nonceResponse =
          await _api.get('/auth/nonce?address=$address');
      final nonce = nonceResponse['nonce'] as String;
      final message = nonceResponse['message'] as String;

      // 3. Sign the nonce with the wallet.
      final messageBytes = Uint8List.fromList(utf8.encode(message));
      final signatureBytes =
          await SolanaWalletAdapter.signMessage(walletName, messageBytes);

      // 4. Base58 encode the signature for the backend.
      final signatureBase58 = _base58Encode(signatureBytes);

      // 5. Verify with backend and get JWT.
      final authResponse = await _api.post('/auth/verify', {
        'address': address,
        'signature': signatureBase58,
        'nonce': nonce,
      });

      final token = authResponse['token'] as String;
      await _api.setToken(token);

      // 6. Connect WebSocket with the JWT.
      _api.connectWebSocket();

      // 7. Fetch user profile from backend.
      final userResponse = await _api.get('/user/$address');

      // 8. Fetch on-chain USDC balance.
      final balanceResponse = await _api.get('/portfolio/balance');
      final platformBalance =
          (balanceResponse['platformBalance'] as num).toDouble();

      state = state.copyWith(
        status: WalletConnectionStatus.connected,
        address: address,
        usdcBalance: platformBalance,
        gamerTag: userResponse['gamerTag'] as String?,
      );
    } on WalletException catch (e) {
      state = state.copyWith(
        status: WalletConnectionStatus.error,
        errorMessage: e.message,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        status: WalletConnectionStatus.error,
        errorMessage: 'Auth failed: ${e.message}',
      );
    } catch (e) {
      state = state.copyWith(
        status: WalletConnectionStatus.error,
        errorMessage: 'Failed to connect: ${e.toString()}',
      );
    }
  }

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

  /// Set the user's gamer tag (persisted to backend).
  Future<void> setGamerTag(String tag) async {
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

  /// Refresh USDC balance from the backend.
  Future<void> refreshBalance() async {
    if (!state.isConnected || state.address == null) return;
    try {
      final response = await _api.get('/portfolio/balance');
      final platformBalance =
          (response['platformBalance'] as num).toDouble();
      state = state.copyWith(usdcBalance: platformBalance);
    } catch (_) {
      // Silently fail, keep existing balance.
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
