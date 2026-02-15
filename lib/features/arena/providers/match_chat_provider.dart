import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';
import '../models/chat_message.dart';

class MatchChatNotifier extends Notifier<List<ChatMessage>> {
  final _api = ApiClient.instance;
  StreamSubscription? _wsSub;
  String _matchId = '';
  String _myAddress = '';
  String _myTag = '';
  int _msgCounter = 0;

  @override
  List<ChatMessage> build() {
    ref.onDispose(() {
      _wsSub?.cancel();
    });
    return const [];
  }

  /// Initialize chat for a match. Call after startMatch().
  void init({
    required String matchId,
    required String myAddress,
    required String myTag,
  }) {
    _matchId = matchId;
    _myAddress = myAddress;
    _myTag = myTag;
    _msgCounter = 0;

    _wsSub?.cancel();
    _wsSub = _api.wsStream
        .where((d) =>
            d['type'] == 'chat_message' && d['matchId'] == _matchId)
        .listen(_onReceive);

    // System message
    state = [
      ChatMessage(
        id: 'sys_start',
        senderTag: '',
        content: 'Match started — good luck!',
        timestamp: DateTime.now(),
        isSystem: true,
      ),
    ];
  }

  /// Send a chat message.
  void sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > 200) return;

    _msgCounter++;
    final msg = ChatMessage(
      id: 'me_$_msgCounter',
      senderTag: _myTag,
      content: trimmed,
      timestamp: DateTime.now(),
      isMe: true,
    );

    // Optimistic local add.
    state = [...state, msg];
    _capMessages();

    // Send via WebSocket.
    _api.wsSend({
      'type': 'chat_message',
      'matchId': _matchId,
      'content': trimmed,
      'senderTag': _myTag,
    });
  }

  void _onReceive(Map<String, dynamic> data) {
    final sender = data['sender'] as String? ?? '';
    // Skip own messages (already added optimistically).
    if (sender == _myAddress) return;

    final senderTag = data['senderTag'] as String? ?? 'Opponent';

    _msgCounter++;
    final msg = ChatMessage(
      id: 'opp_$_msgCounter',
      senderTag: senderTag,
      content: data['content'] as String? ?? '',
      timestamp: data['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );

    state = [...state, msg];
    _capMessages();
  }

  void _capMessages() {
    if (state.length > 100) {
      state = state.sublist(state.length - 100);
    }
  }

  /// Clean up when match ends or user leaves.
  void dispose() {
    _wsSub?.cancel();
    _wsSub = null;
  }
}

final matchChatProvider =
    NotifierProvider<MatchChatNotifier, List<ChatMessage>>(
        MatchChatNotifier.new);
