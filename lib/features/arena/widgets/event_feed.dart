import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/match_event.dart';
import '../providers/match_events_provider.dart';
import '../utils/arena_helpers.dart';

// =============================================================================
// Event Feed — Scrolling list of live match events + toast overlay
// =============================================================================

/// Feed panel for sidebar display (scrolling list of all events).
class EventFeedPanel extends ConsumerStatefulWidget {
  const EventFeedPanel({super.key});

  @override
  ConsumerState<EventFeedPanel> createState() => _EventFeedPanelState();
}

class _EventFeedPanelState extends ConsumerState<EventFeedPanel> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(matchEventsProvider).events;

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_none_rounded,
                size: 32, color: AppTheme.textTertiary),
            const SizedBox(height: 8),
            Text('No events yet',
                style: interStyle(
                    fontSize: 12, color: AppTheme.textTertiary)),
            const SizedBox(height: 4),
            Text('Match events will appear here',
                style: interStyle(
                    fontSize: 10, color: AppTheme.textTertiary)),
          ],
        ),
      );
    }

    // Auto-scroll to bottom when new events arrive.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    return ListView.builder(
      controller: _scrollController,
      itemCount: events.length,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemBuilder: (context, index) {
        return _EventItem(event: events[index]);
      },
    );
  }
}

// =============================================================================
// Event Item — Single event in the feed
// =============================================================================

class _EventItem extends StatelessWidget {
  final MatchEvent event;

  const _EventItem({required this.event});

  @override
  Widget build(BuildContext context) {
    final color = event.color ?? eventColor(event.type);
    final icon = event.icon ?? eventIcon(event.type);
    final ago = _formatAgo(event.timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon circle.
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 12, color: color),
          ),
          const SizedBox(width: 8),

          // Message + timestamp.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.message,
                    style: interStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    )),
                Text(ago,
                    style: interStyle(
                      fontSize: 9,
                      color: AppTheme.textTertiary,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 5) return 'just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

// =============================================================================
// Event Toast — Overlay toast for latest event (positioned top-right)
// =============================================================================

class EventToast extends ConsumerStatefulWidget {
  const EventToast({super.key});

  @override
  ConsumerState<EventToast> createState() => _EventToastState();
}

class _EventToastState extends ConsumerState<EventToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  MatchEvent? _currentEvent;
  String? _lastEventId;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final latest = ref.watch(
        matchEventsProvider.select((s) => s.latestEvent));

    // Show toast when a new event arrives.
    if (latest != null && latest.id != _lastEventId) {
      _lastEventId = latest.id;
      _currentEvent = latest;
      _controller.forward(from: 0);

      // Auto-dismiss after 3 seconds.
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _lastEventId == latest.id) {
          _controller.reverse();
        }
      });
    }

    if (_currentEvent == null) return const SizedBox.shrink();

    final event = _currentEvent!;
    final color = event.color ?? eventColor(event.type);
    final icon = event.icon ?? eventIcon(event.type);

    return Positioned(
      top: 60,
      left: 0,
      right: 0,
      child: Center(
        child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: color.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 12, color: color),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(event.message,
                      style: interStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      )),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
