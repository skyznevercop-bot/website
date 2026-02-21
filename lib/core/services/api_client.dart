import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import '../config/environment.dart';

/// Singleton HTTP + WebSocket client for the SolFight backend.
class ApiClient {
  ApiClient._();
  static final instance = ApiClient._();

  String? _jwtToken;
  web.WebSocket? _ws;
  final _wsController = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  /// Messages queued while WS was disconnected (replayed on reconnect).
  final List<_PendingMessage> _pendingMessages = [];

  /// Message types that are critical enough to queue for replay.
  static const _queueableTypes = {
    'open_position',
    'close_position',
    'partial_close',
  };

  /// Max age for queued messages before they are discarded (60 seconds).
  static const _maxPendingAge = Duration(seconds: 60);

  /// Stream of incoming WebSocket messages.
  Stream<Map<String, dynamic>> get wsStream => _wsController.stream;

  /// Whether the WebSocket is connected.
  bool get isWsConnected => _ws?.readyState == web.WebSocket.OPEN;

  // ── Auth ───────────────────────────────────────────────

  /// Load JWT from storage on app startup.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _jwtToken = prefs.getString(Environment.jwtTokenKey);
  }

  /// Set the JWT token after authentication.
  Future<void> setToken(String token) async {
    _jwtToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Environment.jwtTokenKey, token);
  }

  /// Clear the JWT token on logout.
  Future<void> clearToken() async {
    _jwtToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(Environment.jwtTokenKey);
  }

  bool get hasToken => _jwtToken != null;

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        if (_jwtToken != null) 'Authorization': 'Bearer $_jwtToken',
      };

  // ── REST ───────────────────────────────────────────────

  static const _timeout = Duration(seconds: 15);

  Future<Map<String, dynamic>> get(String path) async {
    final response = await http.get(
      Uri.parse('${Environment.apiBaseUrl}$path'),
      headers: _authHeaders,
    ).timeout(_timeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? body,
    Duration? timeout,
  ]) async {
    final response = await http.post(
      Uri.parse('${Environment.apiBaseUrl}$path'),
      headers: _authHeaders,
      body: body != null ? jsonEncode(body) : null,
    ).timeout(timeout ?? _timeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http.put(
      Uri.parse('${Environment.apiBaseUrl}$path'),
      headers: _authHeaders,
      body: jsonEncode(body),
    ).timeout(_timeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> delete(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final response = await http.delete(
      Uri.parse('${Environment.apiBaseUrl}$path'),
      headers: _authHeaders,
      body: body != null ? jsonEncode(body) : null,
    ).timeout(_timeout);
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(response.statusCode, response.body);
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    throw ApiException(
      response.statusCode,
      body['error'] as String? ?? 'Unknown error',
    );
  }

  // ── WebSocket ──────────────────────────────────────────

  /// Connect to the WebSocket server.
  void connectWebSocket() {
    if (_jwtToken == null) return;

    _ws?.close();
    _reconnectTimer?.cancel();

    // Connect without token in URL — authenticate via first message instead.
    final url = Environment.wsUrl;
    _ws = web.WebSocket(url);

    _ws!.onopen = ((web.Event e) {
      // Send auth as the first message (not in the URL query string).
      _ws!.send(jsonEncode({'type': 'auth', 'token': _jwtToken}).toJS);
    }).toJS;

    _ws!.onmessage = ((web.MessageEvent event) {
      try {
        final data =
            jsonDecode(event.data.dartify().toString())
                as Map<String, dynamic>;

        // On successful auth, replay queued messages and notify listeners.
        if (data['type'] == 'auth_ok') {
          _reconnectAttempts = 0;

          final now = DateTime.now();
          final pending = _pendingMessages
              .where((m) => now.difference(m.queuedAt) < _maxPendingAge)
              .toList();
          _pendingMessages.clear();
          for (final msg in pending) {
            _ws!.send(jsonEncode(msg.data).toJS);
          }

          _wsController.add({'type': 'ws_connected'});
          return;
        }

        _wsController.add(data);
      } catch (e) {
        if (kDebugMode) debugPrint('[WS] Parse error: $e');
      }
    }).toJS;

    _ws!.onclose = ((web.Event e) {
      _scheduleReconnect();
    }).toJS;

    _ws!.onerror = ((web.Event e) {
      _ws?.close();
    }).toJS;
  }

  /// Send a WebSocket message.
  /// Critical messages (position opens/closes) are queued when disconnected
  /// and replayed on reconnect to prevent silent trade loss.
  void wsSend(Map<String, dynamic> data) {
    if (_ws?.readyState == web.WebSocket.OPEN) {
      _ws!.send(jsonEncode(data).toJS);
    } else {
      final type = data['type'] as String?;
      if (type != null && _queueableTypes.contains(type)) {
        _pendingMessages.add(_PendingMessage(data));
      }
    }
  }

  /// Disconnect WebSocket.
  void disconnectWebSocket() {
    _reconnectTimer?.cancel();
    _pendingMessages.clear();
    _ws?.close();
    _ws = null;
  }

  /// Exponential backoff reconnection.
  void _scheduleReconnect() {
    if (_jwtToken == null) return;

    final delay = Duration(
      milliseconds: (1000 * (1 << _reconnectAttempts.clamp(0, 6))),
    );
    _reconnectAttempts++;

    _reconnectTimer = Timer(delay, connectWebSocket);
  }

  /// Dispose resources.
  void dispose() {
    disconnectWebSocket();
    _wsController.close();
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class _PendingMessage {
  final Map<String, dynamic> data;
  final DateTime queuedAt;

  _PendingMessage(this.data) : queuedAt = DateTime.now();
}
