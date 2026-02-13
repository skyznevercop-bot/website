import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

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

  Future<Map<String, dynamic>> get(String path) async {
    final response = await http.get(
      Uri.parse('${Environment.apiBaseUrl}$path'),
      headers: _authHeaders,
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final response = await http.post(
      Uri.parse('${Environment.apiBaseUrl}$path'),
      headers: _authHeaders,
      body: body != null ? jsonEncode(body) : null,
    );
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
    );
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
    );
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
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

    final url = '${Environment.wsUrl}?token=$_jwtToken';
    _ws = web.WebSocket(url);

    _ws!.onopen = ((web.Event e) {
      _reconnectAttempts = 0;
    }).toJS;

    _ws!.onmessage = ((web.MessageEvent event) {
      try {
        final data =
            jsonDecode(event.data.dartify().toString())
                as Map<String, dynamic>;
        _wsController.add(data);
      } catch (_) {}
    }).toJS;

    _ws!.onclose = ((web.Event e) {
      _scheduleReconnect();
    }).toJS;

    _ws!.onerror = ((web.Event e) {
      _ws?.close();
    }).toJS;
  }

  /// Send a WebSocket message.
  void wsSend(Map<String, dynamic> data) {
    if (_ws?.readyState == web.WebSocket.OPEN) {
      _ws!.send(jsonEncode(data).toJS);
    }
  }

  /// Disconnect WebSocket.
  void disconnectWebSocket() {
    _reconnectTimer?.cancel();
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
