import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/environment.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/solana_wallet_adapter.dart';
import '../models/wallet_state.dart';

/// SharedPreferences key for the last connected wallet type.
const _walletTypeKey = 'solfight_wallet_type';

/// Manages wallet connection lifecycle with real Solana wallet extensions
/// and backend JWT authentication.
class WalletNotifier extends Notifier<WalletState> {
  @override
  WalletState build() {
    ref.onDispose(() {
      _refreshTimer?.cancel();
      _wsSubscription?.cancel();
    });
    // Attempt silent reconnection on startup.
    Future.microtask(() => tryReconnect());
    return const WalletState();
  }

  final _api = ApiClient.instance;
  StreamSubscription<Map<String, dynamic>>? _wsSubscription;
  Timer? _refreshTimer;

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
      double? initialPlatformBalance;
      double? initialFrozenBalance;
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

        // JWT obtained — backend is available for balance fetches
        // even if the profile fetch below fails.
        backendAvailable = true;

        // Connect WebSocket with the JWT.
        _api.connectWebSocket();

        // Listen for balance_update events from backend.
        _wsSubscription?.cancel();
        _wsSubscription = _api.wsStream.listen((data) {
          if (data['type'] == 'balance_update') {
            final bal = (data['balance'] as num?)?.toDouble();
            final frozen = (data['frozenBalance'] as num?)?.toDouble();
            if (bal != null) {
              state = state.copyWith(
                platformBalance: bal,
                frozenBalance: frozen ?? state.frozenBalance,
              );
            }
          }
        });

        // Fetch balance + profile concurrently right after auth (non-critical).
        try {
          final balanceResponse = await _api.get('/balance');
          initialPlatformBalance = (balanceResponse['balance'] as num?)?.toDouble();
          initialFrozenBalance = (balanceResponse['frozenBalance'] as num?)?.toDouble();
        } catch (e) {
          if (kDebugMode) debugPrint('[Wallet] Initial balance fetch (non-critical): $e');
        }
        try {
          final userResponse = await _api.get('/user/$address');
          gamerTag = userResponse['gamerTag'] as String?;
        } catch (e) {
          if (kDebugMode) debugPrint('[Wallet] Profile fetch failed (non-critical): $e');
        }
      } catch (e) {
        // Backend unreachable or auth failed — wallet-only mode.
        if (kDebugMode) debugPrint('[Wallet] Backend auth failed: $e');
        backendAvailable = false;
      }

      _backendConnected = backendAvailable;

      // Persist wallet type so we can reconnect after page refresh.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_walletTypeKey, walletName);

      // Mark as connected with balance if we already fetched it.
      state = state.copyWith(
        status: WalletConnectionStatus.connected,
        address: address,
        gamerTag: gamerTag,
        platformBalance: initialPlatformBalance ?? state.platformBalance,
        frozenBalance: initialFrozenBalance ?? state.frozenBalance,
        isBalanceLoading: true,
      );

      // Fetch on-chain USDC balance in background.
      _fetchOnChainUsdcBalance(address).then((onChainBalance) {
        if (kDebugMode) debugPrint('[Wallet] On-chain USDC balance resolved: $onChainBalance');
        state = state.copyWith(usdcBalance: onChainBalance, isBalanceLoading: false);
      }).catchError((e) {
        if (kDebugMode) debugPrint('[Wallet] On-chain USDC balance fetch error: $e');
        state = state.copyWith(usdcBalance: 0, isBalanceLoading: false);
      });

      // If we didn't get the balance during auth, retry in background.
      if (backendAvailable && initialPlatformBalance == null) {
        _fetchPlatformBalanceWithRetry().catchError((e) {
          if (kDebugMode) debugPrint('[Wallet] Platform balance fetch error: $e');
        });
      } else if (!backendAvailable) {
        // Backend was down (cold start). Retry auth + balance after delay.
        _retryBackendAuth(walletName, address);
      }

      _startPeriodicRefresh();
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
    _refreshTimer?.cancel();
    _refreshTimer = null;
    final walletName = state.walletType?.name;
    if (walletName != null) {
      await SolanaWalletAdapter.disconnect(walletName);
    }
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _api.disconnectWebSocket();
    await _api.clearToken();

    // Clear persisted wallet type so we don't try to reconnect.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_walletTypeKey);

    state = const WalletState();
  }

  /// Attempt to silently reconnect using a previously approved wallet.
  /// Called automatically on app startup from [build].
  /// Uses `connectEagerly` which passes `{ onlyIfTrusted: true }` so
  /// no popup is shown — succeeds only if the user previously approved.
  Future<void> tryReconnect() async {
    // Don't reconnect if already connected or connecting.
    if (state.isConnected || state.isConnecting) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final walletName = prefs.getString(_walletTypeKey);
      if (walletName == null) return; // No previous session.

      // Need a stored JWT too — without it we can't auth with the backend.
      if (!_api.hasToken) return;

      if (kDebugMode) debugPrint('[Wallet] Attempting silent reconnect to $walletName…');

      // Eagerly connect — no popup, fails silently if not trusted.
      final result = await SolanaWalletAdapter.connectEagerly(walletName);
      final address = result.publicKey;

      // Validate the stored JWT by fetching /balance (authenticated endpoint).
      // /user/:address is public and won't catch expired JWTs.
      String? gamerTag;
      bool backendAvailable = true;
      double? cachedBalance;
      double? cachedFrozen;
      try {
        final balanceResponse = await _api.get('/balance');
        cachedBalance = (balanceResponse['balance'] as num?)?.toDouble() ?? 0;
        cachedFrozen = (balanceResponse['frozenBalance'] as num?)?.toDouble() ?? 0;

        // JWT is valid — also fetch gamerTag (non-critical, public endpoint).
        try {
          final userResponse = await _api.get('/user/$address');
          gamerTag = userResponse['gamerTag'] as String?;
        } catch (_) {}
      } on ApiException catch (e) {
        if (e.statusCode == 401) {
          // JWT expired — clear session so user re-connects with fresh auth.
          if (kDebugMode) debugPrint('[Wallet] JWT expired — clearing session');
          await _api.clearToken();
          await prefs.remove(_walletTypeKey);
          try { await SolanaWalletAdapter.disconnect(walletName); } catch (_) {}
          return;
        }
        // Other API error (500, etc.) — JWT may still be valid, try balance anyway.
        if (kDebugMode) debugPrint('[Wallet] Balance validation failed (non-critical): $e');
      } catch (e) {
        // Network error / timeout — JWT may still be valid, try balance anyway.
        if (kDebugMode) debugPrint('[Wallet] Balance validation failed (non-critical): $e');
      }

      _backendConnected = backendAvailable;

      // Connect WebSocket with the (possibly refreshed) JWT.
      _api.connectWebSocket();

      // Listen for balance_update events.
      _wsSubscription?.cancel();
      _wsSubscription = _api.wsStream.listen((data) {
        if (data['type'] == 'balance_update') {
          final bal = (data['balance'] as num?)?.toDouble();
          final frozen = (data['frozenBalance'] as num?)?.toDouble();
          if (bal != null) {
            state = state.copyWith(
              platformBalance: bal,
              frozenBalance: frozen ?? state.frozenBalance,
            );
          }
        }
      });

      // Resolve wallet type enum from stored string.
      final walletType = WalletType.values.firstWhere(
        (t) => t.name == walletName,
        orElse: () => WalletType.phantom,
      );

      state = state.copyWith(
        status: WalletConnectionStatus.connected,
        walletType: walletType,
        address: address,
        gamerTag: gamerTag,
        platformBalance: cachedBalance ?? state.platformBalance,
        frozenBalance: cachedFrozen ?? state.frozenBalance,
        isBalanceLoading: true,
      );

      if (kDebugMode) debugPrint('[Wallet] Silent reconnect successful: ${address.substring(0, 8)}…');

      // Fetch on-chain balance in background.
      _fetchOnChainUsdcBalance(address).then((balance) {
        state = state.copyWith(usdcBalance: balance, isBalanceLoading: false);
      }).catchError((e) {
        if (kDebugMode) debugPrint('[Wallet] Reconnect on-chain balance failed: $e');
        state = state.copyWith(usdcBalance: 0, isBalanceLoading: false);
      });

      // Only fetch platform balance if we didn't already get it during validation.
      if (_backendConnected && cachedBalance == null) {
        _fetchPlatformBalanceWithRetry();
      }

      _startPeriodicRefresh();
    } catch (e) {
      // Silent reconnect failed — user will need to connect manually.
      if (kDebugMode) debugPrint('[Wallet] Silent reconnect failed: $e');
    }
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

  /// Refresh both on-chain and platform balances.
  Future<void> refreshBalance() async {
    if (!state.isConnected || state.address == null) return;
    state = state.copyWith(isBalanceLoading: true);
    try {
      final balance = await _fetchOnChainUsdcBalance(state.address!);
      state = state.copyWith(usdcBalance: balance, isBalanceLoading: false);
    } catch (e) {
      if (kDebugMode) debugPrint('[Wallet] refreshBalance on-chain failed: $e');
      state = state.copyWith(usdcBalance: state.usdcBalance ?? 0, isBalanceLoading: false);
    }
    if (_backendConnected) {
      await _fetchPlatformBalance();
    }
  }

  /// Fetch platform balance from backend and update state.
  Future<void> _fetchPlatformBalance() async {
    try {
      final response = await _api.get('/balance');
      final balance = (response['balance'] as num?)?.toDouble() ?? 0;
      final frozen = (response['frozenBalance'] as num?)?.toDouble() ?? 0;
      state = state.copyWith(
        platformBalance: balance,
        frozenBalance: frozen,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Wallet] Platform balance fetch failed: $e');
    }
  }

  /// Fetch platform balance with retries (handles backend cold starts).
  /// Up to 8 attempts over ~60s total to survive Render cold starts.
  Future<void> _fetchPlatformBalanceWithRetry() async {
    for (int attempt = 0; attempt < 8; attempt++) {
      try {
        final response = await _api.get('/balance');
        final balance = (response['balance'] as num?)?.toDouble() ?? 0;
        final frozen = (response['frozenBalance'] as num?)?.toDouble() ?? 0;
        state = state.copyWith(
          platformBalance: balance,
          frozenBalance: frozen,
        );
        _backendConnected = true;
        return; // Success — stop retrying.
      } catch (e) {
        if (kDebugMode) debugPrint('[Wallet] Balance fetch attempt ${attempt + 1}/8 failed: $e');
        if (attempt < 7) {
          // Backoff: 3s, 5s, 7s, 9s, 10s, 10s, 10s (~54s total)
          await Future.delayed(Duration(seconds: (3 + attempt * 2).clamp(3, 10)));
        }
      }
    }
  }

  /// Refresh only the platform balance (called after deposit/withdraw
  /// and whenever the portfolio screen loads).
  Future<void> refreshPlatformBalance() async {
    await _fetchPlatformBalance();
  }

  /// Fetch USDC SPL token balance from Solana RPC with retries.
  /// Uses backend proxy first (reliable, no CORS), falls back to direct RPC.
  static Future<double> _fetchOnChainUsdcBalance(String walletAddress) async {
    // Retry the full RPC sequence up to 3 times.
    for (int attempt = 0; attempt < 3; attempt++) {
      for (final rpcUrl in [
        Environment.solanaRpcUrl,
        Environment.solanaRpcUrlFallback,
        Environment.solanaRpcUrl2,
      ]) {
        final result = await _queryUsdcBalance(walletAddress, rpcUrl);
        if (result != null) return result;
      }
      if (attempt < 2) {
        if (kDebugMode) debugPrint('[Wallet] All RPCs failed attempt ${attempt + 1}/3 — retrying in ${2 * (attempt + 1)}s');
        await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
      }
    }
    if (kDebugMode) debugPrint('[Wallet] All RPC retries exhausted for $walletAddress — returning 0');
    return 0;
  }

  /// Query USDC balance from a specific Solana RPC endpoint.
  /// Returns null on failure so the caller can try the next RPC.
  static Future<double?> _queryUsdcBalance(
      String walletAddress, String rpcUrl) async {
    try {
      if (kDebugMode) debugPrint('[Wallet] Querying USDC balance from $rpcUrl for ${walletAddress.substring(0, 8)}…');
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
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        if (kDebugMode) debugPrint('[Wallet] RPC $rpcUrl returned status ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data.containsKey('error')) {
        if (kDebugMode) debugPrint('[Wallet] RPC $rpcUrl returned error: ${data['error']}');
        return null;
      }

      final result = data['result'] as Map<String, dynamic>?;
      final accounts = result?['value'] as List<dynamic>?;
      if (accounts == null || accounts.isEmpty) {
        if (kDebugMode) debugPrint('[Wallet] No USDC token accounts found for ${walletAddress.substring(0, 8)}…');
        return 0;
      }

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
      if (kDebugMode) debugPrint('[Wallet] USDC balance from $rpcUrl: $total');
      return total;
    } catch (e) {
      if (kDebugMode) debugPrint('[Wallet] RPC $rpcUrl failed: $e');
      return null;
    }
  }

  /// Retry backend auth after a cold-start failure.
  /// Waits for the backend to wake up, then re-attempts auth + balance fetch.
  Future<void> _retryBackendAuth(String walletName, String address) async {
    for (int attempt = 0; attempt < 3; attempt++) {
      await Future.delayed(Duration(seconds: 15 + (attempt * 15)));
      if (!state.isConnected || state.address != address) return;

      if (kDebugMode) debugPrint('[Wallet] Retry backend auth attempt ${attempt + 1}/3');

      try {
        final nonceResponse = await _api.get('/auth/nonce?address=$address');
        final nonce = nonceResponse['nonce'] as String;
        final message = nonceResponse['message'] as String;

        final messageBytes = Uint8List.fromList(utf8.encode(message));
        final signatureBytes =
            await SolanaWalletAdapter.signMessage(walletName, messageBytes);
        final signatureBase58 = _base58Encode(signatureBytes);

        final authResponse = await _api.post('/auth/verify', {
          'address': address,
          'signature': signatureBase58,
          'nonce': nonce,
        });

        final token = authResponse['token'] as String;
        await _api.setToken(token);
        _backendConnected = true;

        _api.connectWebSocket();
        _wsSubscription?.cancel();
        _wsSubscription = _api.wsStream.listen((data) {
          if (data['type'] == 'balance_update') {
            final bal = (data['balance'] as num?)?.toDouble();
            final frozen = (data['frozenBalance'] as num?)?.toDouble();
            if (bal != null) {
              state = state.copyWith(
                platformBalance: bal,
                frozenBalance: frozen ?? state.frozenBalance,
              );
            }
          }
        });

        // Fetch profile + balance now that backend is alive.
        try {
          final userResponse = await _api.get('/user/$address');
          final tag = userResponse['gamerTag'] as String?;
          if (tag != null) state = state.copyWith(gamerTag: tag);
        } catch (_) {}

        await _fetchPlatformBalance();

        if (kDebugMode) debugPrint('[Wallet] Backend auth retry succeeded');
        return;
      } catch (e) {
        if (kDebugMode) debugPrint('[Wallet] Backend auth retry ${attempt + 1}/3 failed: $e');
      }
    }
  }

  /// Start a periodic timer that refreshes balances every 45 seconds.
  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      _silentRefresh();
    });
  }

  /// Silent refresh — does not set isBalanceLoading to avoid UI flicker.
  Future<void> _silentRefresh() async {
    if (!state.isConnected || state.address == null) return;
    try {
      final balance = await _fetchOnChainUsdcBalance(state.address!);
      state = state.copyWith(usdcBalance: balance);
    } catch (e) {
      if (kDebugMode) debugPrint('[Wallet] Silent refresh on-chain failed: $e');
    }
    // Always attempt platform balance refresh — the backend may have
    // come back online since initial connection.
    await _fetchPlatformBalance();
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
