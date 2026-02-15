import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../models/chat_message.dart';
import '../providers/match_chat_provider.dart';
import '../providers/trading_provider.dart';

/// Chat panel for the Arena — shown as a sidebar (desktop) or tab (mobile).
class MatchChatPanel extends ConsumerStatefulWidget {
  final VoidCallback? onClose; // Desktop only — hides sidebar.

  const MatchChatPanel({super.key, this.onClose});

  @override
  ConsumerState<MatchChatPanel> createState() => _MatchChatPanelState();
}

class _MatchChatPanelState extends ConsumerState<MatchChatPanel> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    ref.read(matchChatProvider.notifier).sendMessage(text);
    _controller.clear();
    _focusNode.requestFocus();
    // Scroll to bottom after message added.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(matchChatProvider);
    final matchActive = ref.watch(tradingProvider).matchActive;

    return Container(
      color: AppTheme.background,
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: AppTheme.background,
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline_rounded,
                    size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'Chat',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (messages.where((m) => !m.isSystem).isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.solanaPurple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${messages.where((m) => !m.isSystem).length}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.solanaPurple,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (widget.onClose != null)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: widget.onClose,
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: AppTheme.textTertiary),
                    ),
                  ),
              ],
            ),
          ),

          // ── Message List ────────────────────────────────────
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            size: 32,
                            color: AppTheme.textTertiary.withValues(alpha: 0.5)),
                        const SizedBox(height: 8),
                        Text(
                          'No messages yet',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      return _ChatBubble(
                        message: msg,
                        relativeTime: _relativeTime(msg.timestamp),
                      );
                    },
                  ),
          ),

          // ── Input Bar ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppTheme.background,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: Responsive.value<double>(context,
                        mobile: 44, desktop: 36),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      enabled: matchActive,
                      maxLength: 200,
                      maxLines: 1,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: matchActive
                            ? 'Send a message...'
                            : 'Match ended',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textTertiary,
                        ),
                        counterText: '',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _send(),
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                MouseRegion(
                  cursor: matchActive
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.basic,
                  child: GestureDetector(
                    onTap: matchActive ? _send : null,
                    child: Container(
                      width: Responsive.value<double>(context,
                          mobile: 44, desktop: 36),
                      height: Responsive.value<double>(context,
                          mobile: 44, desktop: 36),
                      decoration: BoxDecoration(
                        color: matchActive
                            ? AppTheme.solanaPurple
                            : AppTheme.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.send_rounded,
                        size: 16,
                        color: matchActive
                            ? Colors.white
                            : AppTheme.textTertiary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Chat Bubble ────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final String relativeTime;

  const _ChatBubble({required this.message, required this.relativeTime});

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Text(
            message.content,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: AppTheme.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final isMe = message.isMe;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(
                message.senderTag,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textTertiary,
                ),
              ),
            ),
          Container(
            constraints: const BoxConstraints(maxWidth: 220),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isMe
                  ? AppTheme.solanaPurple.withValues(alpha: 0.15)
                  : AppTheme.surfaceAlt,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(isMe ? 12 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 12),
              ),
              border: Border.all(
                color: isMe
                    ? AppTheme.solanaPurple.withValues(alpha: 0.25)
                    : AppTheme.border,
                width: 0.5,
              ),
            ),
            child: Text(
              message.content,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textPrimary,
                height: 1.35,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              top: 2,
              left: isMe ? 0 : 4,
              right: isMe ? 4 : 0,
            ),
            child: Text(
              relativeTime,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: AppTheme.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
