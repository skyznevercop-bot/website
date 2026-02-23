import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../arena/models/chat_message.dart';
import '../../arena/models/match_event.dart';
import '../../arena/models/trading_models.dart';
import '../../arena/utils/arena_helpers.dart';
import '../../arena/widgets/chart_toolbar.dart';
import '../../arena/widgets/lw_chart_widget.dart';
import '../models/spectator_models.dart';
import '../providers/spectator_provider.dart';

// =============================================================================
// Spectate Screen — Read-only view of a live match
// =============================================================================

class SpectateScreen extends ConsumerStatefulWidget {
  final String matchId;

  const SpectateScreen({super.key, required this.matchId});

  @override
  ConsumerState<SpectateScreen> createState() => _SpectateScreenState();
}

class _SpectateScreenState extends ConsumerState<SpectateScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(spectatorProvider.notifier).startSpectating(widget.matchId);
    });
  }

  @override
  void dispose() {
    // Use container to safely access notifier during dispose.
    ProviderScope.containerOf(context)
        .read(spectatorProvider.notifier)
        .stopSpectating();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(spectatorProvider);
    final isMobile = Responsive.isMobile(context);

    if (state.isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppTheme.solanaPurple,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Connecting to match...',
                style: interStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          Column(
            children: [
              _SpectatorHud(state: state),
              if (!state.matchEnded) _SpectatorBattleBar(state: state),
              Expanded(
                child: isMobile
                    ? _MobileLayout(state: state)
                    : _DesktopLayout(state: state),
              ),
            ],
          ),

          // Match result overlay.
          if (state.matchEnded)
            Positioned.fill(
              child: _SpectatorResultOverlay(state: state),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Spectator HUD — Back + Timer + Bet + Spectator Count + LIVE badge
// =============================================================================

class _SpectatorHud extends StatelessWidget {
  final SpectatorState state;

  const _SpectatorHud({required this.state});

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final remaining = state.matchTimeRemainingSeconds;
    final total = state.durationSeconds;
    final progress = total > 0 ? remaining / total : 0.0;
    final phase = computePhase(remaining, total);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: isMobile ? 52 : 56,
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16),
          decoration: const BoxDecoration(
            color: AppTheme.background,
            border: Border(
              bottom: BorderSide(color: AppTheme.border, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              // Back button.
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => context.go(AppConstants.playRoute),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back_rounded,
                          size: 18, color: AppTheme.textSecondary),
                      if (!isMobile) ...[
                        const SizedBox(width: 6),
                        Text('SolFight',
                            style: interStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            )),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // LIVE badge.
              if (!state.matchEnded)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppTheme.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('LIVE',
                          style: interStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.error,
                            letterSpacing: 1,
                          )),
                    ],
                  ),
                ),

              const Spacer(),

              // Timer + phase.
              if (!state.matchEnded)
                _SpectatorTimer(
                  seconds: remaining,
                  progress: progress,
                  phase: phase,
                  isMobile: isMobile,
                ),

              const Spacer(),

              // Bet amount.
              if (state.betAmount > 0 && !isMobile)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '\$${state.betAmount.toStringAsFixed(0)} bet',
                      style: interStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),

              // Spectator count.
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.visibility_rounded,
                        size: 13, color: AppTheme.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      '${state.spectatorCount}',
                      style: interStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                        tabularFigures: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Time progress bar.
        if (!state.matchEnded)
          _TimeProgressBar(progress: progress, seconds: remaining),
      ],
    );
  }
}

// =============================================================================
// Spectator Timer — Reused pattern from ArenaHud
// =============================================================================

class _SpectatorTimer extends StatelessWidget {
  final int seconds;
  final double progress;
  final MatchPhase phase;
  final bool isMobile;

  const _SpectatorTimer({
    required this.seconds,
    required this.progress,
    required this.phase,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final isLastStand = phase == MatchPhase.lastStand;
    final isFinalSprint = phase == MatchPhase.finalSprint;
    final timerColor = isLastStand
        ? AppTheme.error
        : isFinalSprint
            ? AppTheme.warning
            : AppTheme.textPrimary;
    final pColor = phaseColor(phase);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            strokeWidth: 2.5,
            backgroundColor: AppTheme.border,
            color: pColor,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          fmtTime(seconds),
          style: interStyle(
            fontSize: isLastStand ? 20 : isFinalSprint ? 18 : 16,
            fontWeight: FontWeight.w800,
            color: timerColor,
            tabularFigures: true,
            letterSpacing: 1.0,
          ),
        ),
        if (!isMobile && phase != MatchPhase.intro) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: pColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: pColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              phaseLabel(phase),
              style: interStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: pColor,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// Time Progress Bar
// =============================================================================

class _TimeProgressBar extends StatelessWidget {
  final double progress;
  final int seconds;

  const _TimeProgressBar({required this.progress, required this.seconds});

  @override
  Widget build(BuildContext context) {
    final Color barColor;
    if (seconds <= 30) {
      barColor = AppTheme.error;
    } else if (seconds <= 60) {
      barColor = AppTheme.warning;
    } else {
      barColor = AppTheme.solanaPurple;
    }

    return Container(
      height: 3,
      width: double.infinity,
      color: AppTheme.border,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 900),
          curve: Curves.linear,
          decoration: BoxDecoration(
            color: barColor,
            boxShadow: seconds <= 60
                ? [
                    BoxShadow(
                      color: barColor.withValues(alpha: 0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Spectator Battle Bar — Tug-of-war adapted for spectator state
// =============================================================================

class _SpectatorBattleBar extends StatelessWidget {
  final SpectatorState state;

  const _SpectatorBattleBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final p1Roi = state.player1.roi;
    final p2Roi = state.player2.roi;

    // Sigmoid mapping: diff → 0..1 (0.5 = tied).
    final diff = p1Roi - p2Roi;
    final p1Fraction =
        (0.5 + (diff / (diff.abs() + 5)) * 0.45).clamp(0.15, 0.85);

    const p1Color = AppTheme.solanaPurple;
    const p2Color = Color(0xFFFF6B35);

    final p1Ahead = p1Roi > p2Roi;
    final isTied = (p1Roi - p2Roi).abs() < 0.01;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border:
            Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: Row(
        children: [
          // Player 1.
          _BattleAvatarLabel(
            tag: state.player1.gamerTag,
            roi: p1Roi,
            color: p1Color,
            isLeading: p1Ahead && !isTied,
            alignment: CrossAxisAlignment.start,
          ),
          const SizedBox(width: 8),

          // Tug-of-war bar.
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: SizedBox(
                    height: 10,
                    child: Row(
                      children: [
                        Flexible(
                          flex: (p1Fraction * 1000).round(),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeInOutCubic,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                p1Color.withValues(alpha: 0.5),
                                p1Color,
                              ]),
                              boxShadow: p1Ahead
                                  ? [
                                      BoxShadow(
                                        color:
                                            p1Color.withValues(alpha: 0.4),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                        Container(width: 2, color: AppTheme.background),
                        Flexible(
                          flex: ((1.0 - p1Fraction) * 1000).round(),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeInOutCubic,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                p2Color,
                                p2Color.withValues(alpha: 0.5),
                              ]),
                              boxShadow: !p1Ahead && !isTied
                                  ? [
                                      BoxShadow(
                                        color:
                                            p2Color.withValues(alpha: 0.4),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Center diamond.
                Positioned(
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Transform.rotate(
                      angle: 0.785,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          border: Border.all(
                            color: isTied
                                ? AppTheme.textTertiary
                                : p1Ahead
                                    ? p1Color
                                    : p2Color,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Player 2.
          _BattleAvatarLabel(
            tag: state.player2.gamerTag,
            roi: p2Roi,
            color: p2Color,
            isLeading: !p1Ahead && !isTied,
            alignment: CrossAxisAlignment.end,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Battle Avatar Label — Mirrors arena's _AvatarLabel
// =============================================================================

class _BattleAvatarLabel extends StatelessWidget {
  final String tag;
  final double roi;
  final Color color;
  final bool isLeading;
  final CrossAxisAlignment alignment;

  const _BattleAvatarLabel({
    required this.tag,
    required this.roi,
    required this.color,
    required this.isLeading,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == CrossAxisAlignment.start;

    return SizedBox(
      width: 110,
      child: Row(
        mainAxisAlignment:
            isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (!isLeft) ...[
            _buildStats(isLeft),
            const SizedBox(width: 6),
          ],
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: isLeading ? 0.2 : 0.08),
              border: Border.all(
                color: isLeading ? color : AppTheme.border,
                width: 1.5,
              ),
              boxShadow: isLeading
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                tag.isNotEmpty ? tag[0].toUpperCase() : '?',
                style: interStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isLeading ? color : AppTheme.textTertiary,
                ),
              ),
            ),
          ),
          if (isLeft) ...[
            const SizedBox(width: 6),
            _buildStats(isLeft),
          ],
        ],
      ),
    );
  }

  Widget _buildStats(bool isLeft) {
    return Flexible(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment:
            isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Text(
            tag,
            style: interStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isLeading ? color : AppTheme.textTertiary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            fmtPercent(roi),
            style: interStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: pnlColor(roi),
              tabularFigures: true,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Spectator Asset Bar — Displays prices from spectator state
// =============================================================================

class _SpectatorAssetBar extends StatelessWidget {
  final SpectatorState state;

  const _SpectatorAssetBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Container(
      height: 42,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border:
            Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: Row(
        children: state.prices.entries.map((entry) {
          final color = assetColor(entry.key);
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 8 : 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.border.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        entry.key[0],
                        style: interStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    entry.key,
                    style: interStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '\$${fmtPrice(entry.value)}',
                    style: interStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textTertiary,
                      tabularFigures: true,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// =============================================================================
// Desktop Layout — Chart (65%) | Events/Chat (35%)
// =============================================================================

class _DesktopLayout extends StatelessWidget {
  final SpectatorState state;

  const _DesktopLayout({required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Chart column.
        Expanded(
          flex: 65,
          child: Column(
            children: [
              _SpectatorAssetBar(state: state),
              const ChartToolbar(),
              const Expanded(child: LWChart()),
            ],
          ),
        ),

        Container(width: 1, color: AppTheme.border),

        // Events / Chat sidebar.
        Expanded(
          flex: 35,
          child: _EventsChatTabs(state: state),
        ),
      ],
    );
  }
}

// =============================================================================
// Mobile Layout — Chart + Events/Chat tabs
// =============================================================================

class _MobileLayout extends StatelessWidget {
  final SpectatorState state;

  const _MobileLayout({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SpectatorAssetBar(state: state),
        const ChartToolbar(),
        const Expanded(flex: 6, child: LWChart()),
        Container(height: 1, color: AppTheme.border),
        Expanded(
          flex: 4,
          child: _EventsChatTabs(state: state),
        ),
      ],
    );
  }
}

// =============================================================================
// Events / Chat Tabs
// =============================================================================

class _EventsChatTabs extends StatelessWidget {
  final SpectatorState state;

  const _EventsChatTabs({required this.state});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: AppTheme.background,
            child: TabBar(
              labelColor: AppTheme.solanaPurple,
              unselectedLabelColor: AppTheme.textTertiary,
              indicatorColor: AppTheme.solanaPurple,
              indicatorWeight: 2,
              dividerHeight: 1,
              dividerColor: AppTheme.border,
              labelStyle:
                  GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notifications_none_rounded, size: 14),
                      const SizedBox(width: 4),
                      const Text('Events'),
                      if (state.events.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.solanaPurple.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${state.events.length}',
                            style: interStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.solanaPurple,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                      const SizedBox(width: 4),
                      const Text('Chat'),
                      if (state.chatMessages.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.solanaPurple.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${state.chatMessages.length}',
                            style: interStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.solanaPurple,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _SpectatorEventFeed(events: state.events),
                _SpectatorChat(
                  messages: state.chatMessages,
                  matchEnded: state.matchEnded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Spectator Event Feed — Renders events directly (no provider dependency)
// =============================================================================

class _SpectatorEventFeed extends StatefulWidget {
  final List<MatchEvent> events;

  const _SpectatorEventFeed({required this.events});

  @override
  State<_SpectatorEventFeed> createState() => _SpectatorEventFeedState();
}

class _SpectatorEventFeedState extends State<_SpectatorEventFeed> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_SpectatorEventFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.events.length > oldWidget.events.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_none_rounded,
                size: 32, color: AppTheme.textTertiary),
            const SizedBox(height: 8),
            Text('No events yet',
                style:
                    interStyle(fontSize: 12, color: AppTheme.textTertiary)),
            const SizedBox(height: 4),
            Text('Match events will appear here',
                style:
                    interStyle(fontSize: 10, color: AppTheme.textTertiary)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: widget.events.length,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemBuilder: (context, index) {
        final event = widget.events[index];
        final color = event.color ?? eventColor(event.type);
        final icon = event.icon ?? eventIcon(event.type);
        final ago = _formatAgo(event.timestamp);

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
      },
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
// Spectator Chat — Read-only view of match chat
// =============================================================================

class _SpectatorChat extends StatefulWidget {
  final List<ChatMessage> messages;
  final bool matchEnded;

  const _SpectatorChat({required this.messages, required this.matchEnded});

  @override
  State<_SpectatorChat> createState() => _SpectatorChatState();
}

class _SpectatorChatState extends State<_SpectatorChat> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_SpectatorChat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length > oldWidget.messages.length) {
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
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Message list.
        Expanded(
          child: widget.messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded,
                          size: 32,
                          color:
                              AppTheme.textTertiary.withValues(alpha: 0.5)),
                      const SizedBox(height: 8),
                      Text('No messages yet',
                          style: interStyle(
                              fontSize: 12, color: AppTheme.textTertiary)),
                      const SizedBox(height: 4),
                      Text('Player chat will appear here',
                          style: interStyle(
                              fontSize: 10, color: AppTheme.textTertiary)),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  itemCount: widget.messages.length,
                  itemBuilder: (context, index) {
                    final msg = widget.messages[index];
                    return _SpectatorChatBubble(
                      message: msg,
                      relativeTime: _relativeTime(msg.timestamp),
                    );
                  },
                ),
        ),

        // Spectating indicator (instead of input bar).
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: AppTheme.background,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.visibility_rounded,
                  size: 14, color: AppTheme.textTertiary),
              const SizedBox(width: 6),
              Text(
                'Spectating — chat is read-only',
                style: interStyle(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Spectator Chat Bubble
// =============================================================================

class _SpectatorChatBubble extends StatelessWidget {
  final ChatMessage message;
  final String relativeTime;

  const _SpectatorChatBubble({
    required this.message,
    required this.relativeTime,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 12, color: AppTheme.textTertiary),
              const SizedBox(width: 6),
              Text(message.content,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: AppTheme.textTertiary,
                  ),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    // Both players use left-aligned bubbles — spectator doesn't have a "me".
    const borderColor = Color(0xFFFF6B35);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 2),
            child: Text(message.senderTag,
                style: interStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textTertiary,
                )),
          ),
          Container(
            constraints: const BoxConstraints(maxWidth: 220),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(12),
              ),
              border: Border(
                left: BorderSide(
                  color: borderColor.withValues(alpha: 0.6),
                  width: 3,
                ),
              ),
            ),
            child: Text(message.content,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                  height: 1.35,
                )),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4),
            child: Text(relativeTime,
                style: interStyle(
                  fontSize: 10,
                  color: AppTheme.textTertiary,
                )),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Spectator Result Overlay — Simplified match result for spectators
// =============================================================================

class _SpectatorResultOverlay extends StatelessWidget {
  final SpectatorState state;

  const _SpectatorResultOverlay({required this.state});

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isTie = state.isTie;
    final isForfeit = state.isForfeit;
    final winnerTag = _getWinnerTag();
    final loserTag = _getLoserTag();

    final resultText = isTie ? 'DRAW' : '$winnerTag WINS';
    final resultColor = isTie
        ? AppTheme.textSecondary
        : const Color(0xFFFFD700);

    final subtitleText = isTie
        ? 'Both players matched ROI'
        : isForfeit
            ? '$loserTag forfeited'
            : '$winnerTag outperformed $loserTag';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.go(AppConstants.playRoute),
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Absorb taps on card.
            child: Container(
              constraints:
                  BoxConstraints(maxWidth: isMobile ? double.infinity : 480),
              margin: EdgeInsets.all(isMobile ? 16 : 32),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: resultColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: resultColor.withValues(alpha: 0.08),
                    blurRadius: 80,
                    spreadRadius: 20,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Result header.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        resultColor.withValues(alpha: 0.12),
                        resultColor.withValues(alpha: 0.03),
                      ], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: resultColor.withValues(alpha: 0.12),
                          ),
                          child: Icon(
                            isTie
                                ? Icons.balance_rounded
                                : Icons.emoji_events_rounded,
                            size: 28,
                            color: resultColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          resultText,
                          style: interStyle(
                            fontSize: isMobile ? 24 : 32,
                            fontWeight: FontWeight.w900,
                            color: resultColor,
                            letterSpacing: 4,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitleText,
                          style: interStyle(
                              fontSize: 13, color: AppTheme.textTertiary),
                        ),
                      ],
                    ),
                  ),

                  // ROI comparison.
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: _SpectatorRoiComparison(state: state),
                  ),

                  // Back to lobby button.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => context.go(AppConstants.playRoute),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: AppTheme.purpleGradient,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.solanaPurple
                                      .withValues(alpha: 0.25),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.arrow_back_rounded,
                                      size: 16, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Back to Lobby',
                                    style: interStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getWinnerTag() {
    if (state.winner == state.player1.address) return state.player1.gamerTag;
    if (state.winner == state.player2.address) return state.player2.gamerTag;
    return 'Winner';
  }

  String _getLoserTag() {
    if (state.winner == state.player1.address) return state.player2.gamerTag;
    if (state.winner == state.player2.address) return state.player1.gamerTag;
    return 'Loser';
  }
}

// =============================================================================
// Spectator ROI Comparison — Shows both players side by side
// =============================================================================

class _SpectatorRoiComparison extends StatelessWidget {
  final SpectatorState state;

  const _SpectatorRoiComparison({required this.state});

  @override
  Widget build(BuildContext context) {
    final isP1Winner = state.winner == state.player1.address;
    final isP2Winner = state.winner == state.player2.address;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Text(
            'FINAL PERFORMANCE',
            style: interStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.textTertiary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _playerRoiColumn(
                    tag: state.player1.gamerTag,
                    roi: state.player1.roi,
                    isChampion: isP1Winner,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 1, height: 20, color: AppTheme.border),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text('VS',
                            style: interStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textTertiary,
                            )),
                      ),
                      Container(width: 1, height: 20, color: AppTheme.border),
                    ],
                  ),
                ),
                Expanded(
                  child: _playerRoiColumn(
                    tag: state.player2.gamerTag,
                    roi: state.player2.roi,
                    isChampion: isP2Winner,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _playerRoiColumn({
    required String tag,
    required double roi,
    required bool isChampion,
  }) {
    const gold = Color(0xFFFFD700);

    return Column(
      children: [
        if (isChampion)
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Icon(Icons.emoji_events_rounded, size: 20, color: gold),
          ),
        Text(
          tag,
          style: interStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          fmtPercent(roi),
          style: interStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: pnlColor(roi),
            tabularFigures: true,
          ),
        ),
      ],
    );
  }
}
