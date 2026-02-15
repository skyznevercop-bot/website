/// A single chat message exchanged between opponents during a match.
class ChatMessage {
  final String id;
  final String senderTag;
  final String content;
  final DateTime timestamp;
  final bool isMe;
  final bool isSystem;

  const ChatMessage({
    required this.id,
    required this.senderTag,
    required this.content,
    required this.timestamp,
    this.isMe = false,
    this.isSystem = false,
  });
}
