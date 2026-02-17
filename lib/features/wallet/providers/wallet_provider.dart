import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/environment.dart';
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

        backendAvailable = true;
      } catch (_) {
        // Backend unreachable — wallet-only mode.
        backendAvailable = false;
      }

      _backendConnected = backendAvailable;

      // Mark as connected immediately — don't block on the on-chain balance fetch.
      state = state.copyWith(
        status: WalletConnectionStatus.connected,
        address: address,
        usdcBalance: 0,
        gamerTag: gamerTag,
      );

      // Fetch on-chain USDC balance in the background and update when ready.
      _fetchOnChainUsdcBalance(address).then((onChainBalance) {
        state = state.copyWith(usdcBalance: onChainBalance);
      }).catchError((_) {});
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

  /// Refresh USDC balance from on-chain (always uses on-chain for now).
  Future<void> refreshBalance() async {
    if (!state.isConnected || state.address == null) return;
    try {
      final balance = await _fetchOnChainUsdcBalance(state.address!);
      state = state.copyWith(usdcBalance: balance);
    } catch (_) {
      // Silently fail, keep existing balance.
    }
  }

  /// Fetch USDC SPL token balance directly from Solana RPC via Dart HTTP.
  /// Tries primary RPC first, falls back to secondary if it fails.
  static Future<double> _fetchOnChainUsdcBalance(String walletAddress) async {
    // Try primary RPC, then fallback.
    for (final rpcUrl in [
      Environment.solanaRpcUrl,
      Environment.solanaRpcUrlFallback,
    ]) {
      final result = await _queryUsdcBalance(walletAddress, rpcUrl);
      if (result != null) return result;
    }
    return 0;
  }

  /// Query USDC balance from a specific Solana RPC endpoint.
  /// Returns null on failure so the caller can try the next RPC.
  static Future<double?> _queryUsdcBalance(
      String walletAddress, String rpcUrl) async {
    try {
      final response = await http.post(
        Uri.parse(rpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'getTokenAccountsByOwner',
          'params': [
            walletAddress,
            {'mint': Environment.usdcMint},
            {'encoding': 'jsonParsed'},
          ],
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data.containsKey('error')) return null;

      final result = data['result'] as Map<String, dynamic>?;
      final accounts = result?['value'] as List<dynamic>?;
      if (accounts == null || accounts.isEmpty) return 0;

      double total = 0;
      for (final account in accounts) {
        try {
          final info = account['account']['data']['parsed']['info']
              as Map<String, dynamic>;
          final tokenAmount = info['tokenAmount'] as Map<String, dynamic>;
          final uiAmount = tokenAmount['uiAmountString'] as String? ?? '0';
          total += double.tryParse(uiAmount) ?? 0;
        } catch (_) {
          continue;
        }
      }
      return total;
    } catch (e) {
      if (kDebugMode) debugPrint('[Wallet] RPC $rpcUrl failed: $e');
      return null;
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
