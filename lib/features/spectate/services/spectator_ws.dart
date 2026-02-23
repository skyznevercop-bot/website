import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';

import 'package:web/web.dart' as web;

import '../../../core/config/environment.dart';

/// Lightweight WebSocket wrapper for spectator connections.
///
/// Separate from [ApiClient] to allow unauthenticated spectating
/// without interfering with the player's authenticated connection.
class SpectatorWs {
  web.WebSocket? _ws;
  final _streamController = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  String? _matchId;
  bool _disposed = false;

  Stream<Map<String, dynamic>> get stream => _streamController.stream;
  bool get isConnected =>
      _ws != null && _ws!.readyState == web.WebSocket.OPEN;

  void connect(String matchId) {
    _matchId = matchId;
    _disposed = false;
    _doConnect();
  }

  void _doConnect() {
    if (_disposed || _matchId == null) return;

    try {
      _ws = web.WebSocket(Environment.wsUrl);

      _ws!.onopen = ((web.Event e) {
        _reconnectAttempt = 0;
        // Send spectate_match as first message (no auth needed).
        _ws!.send(
          jsonEncode({'type': 'spectate_match', 'matchId': _matchId}).toJS,
        );
      }).toJS;

      _ws!.onmessage = ((web.MessageEvent event) {
        try {
          final data = jsonDecode(event.data.dartify().toString())
              as Map<String, dynamic>;
          if (!_streamController.isClosed) {
            _streamController.add(data);
          }
        } catch (_) {}
      }).toJS;

      _ws!.onclose = ((web.CloseEvent event) {
        if (!_disposed) {
          _scheduleReconnect();
        }
      }).toJS;

      _ws!.onerror = ((web.Event event) {
        _ws?.close();
      }).toJS;
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    final delay = min(pow(2, _reconnectAttempt).toInt(), 30);
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: delay), _doConnect);
  }

  void disconnect() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _matchId = null;
    try {
      _ws?.close();
    } catch (_) {}
    _ws = null;
  }

  void dispose() {
    disconnect();
    _streamController.close();
  }
}
