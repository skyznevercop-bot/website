import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../providers/match_chat_provider.dart';
import '../providers/match_events_provider.dart';
import '../providers/price_feed_provider.dart';
import '../providers/trading_provider.dart';
import '../widgets/arena_hud.dart';
import '../widgets/asset_bar.dart';
import '../widgets/battle_bar.dart';
import '../widgets/chart_toolbar.dart';
import '../widgets/event_feed.dart';
import '../widgets/lw_chart_widget.dart';
import '../widgets/match_chat_panel.dart';
import '../widgets/match_intro_overlay.dart';
import '../widgets/match_result_overlay.dart';
import '../widgets/order_panel.dart';
import '../widgets/phase_banner.dart';
import '../widgets/positions_panel.dart';
import '../../wallet/providers/wallet_provider.dart';

// =============================================================================
// Arena Screen — Main orchestrator (v2: gaming HUD, battle bar, event feed)
// =============================================================================

class ArenaScreen extends ConsumerStatefulWidget {
  final int durationSeconds;
  final double betAmount;
  final String? matchId;
  final String? opponentAddress;
  final String? opponentGamerTag;
  final int? endTime;
  final bool isPracticeMode;

  const ArenaScreen({
    super.key,
    required this.durationSeconds,
    required this.betAmount,
    this.matchId,
    this.opponentAddress,
    this.opponentGamerTag,
    this.endTime,
    this.isPracticeMode = false,
  });

  @override
  ConsumerState<ArenaScreen> createState() => _ArenaScreenState();
}

class _ArenaScreenState extends ConsumerState<ArenaScreen> {
  bool _chatOpen = false;
  bool _showIntro = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initMatch();
    });
  }

  void _initMatch() {
    if (widget.isPracticeMode) {
      ref.read(tradingProvider.notifier).startPracticeMatch(
            durationSeconds: widget.durationSeconds,
          );
      return;
    }

    int remaining = widget.durationSeconds;
    if (widget.endTime != null) {
      remaining =
          ((widget.endTime! - DateTime.now().millisecondsSinceEpoch) / 1000)
              .round()
              .clamp(0, widget.durationSeconds);
    }

    final arenaUri = Uri(
      path: AppConstants.arenaRoute,
      queryParameters: {
        'd': widget.durationSeconds.toString(),
        'bet': widget.betAmount.toString(),
        if (widget.matchId != null) 'matchId': widget.matchId!,
        if (widget.opponentAddress != null) 'opp': widget.opponentAddress!,
        if (widget.opponentGamerTag != null)
          'oppTag': widget.opponentGamerTag!,
        if (widget.endTime != null) 'et': widget.endTime.toString(),
      },
    ).toString();

    ref.read(tradingProvider.notifier).startMatch(
          durationSeconds: remaining,
          betAmount: widget.betAmount,
          matchId: widget.matchId,
          opponentAddress: widget.opponentAddress,
          opponentGamerTag: widget.opponentGamerTag,
          arenaRoute: arenaUri,
        );

    final wallet = ref.read(walletProvider);
    ref.read(matchChatProvider.notifier).init(
          matchId: widget.matchId ?? '',
          myAddress: wallet.address ?? '',
          myTag: wallet.gamerTag ?? 'You',
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tradingProvider);
    final isMobile = Responsive.isMobile(context);

    // Bridge price feed → trading state.
    ref.listen<Map<String, double>>(priceFeedProvider, (_, prices) {
      ref.read(tradingProvider.notifier).updatePrices(prices);
    });

    // Keep match events provider alive (it listens to tradingProvider).
    ref.watch(matchEventsProvider);

    final showOverlay = !state.matchActive && state.matchId != null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          Column(
            children: [
              // ── Gaming HUD (replaces toolbar) ──
              ArenaHud(
                state: state,
                durationSeconds: widget.durationSeconds,
              ),

              // ── Battle Bar (tug-of-war) — hidden in practice mode ──
              if (state.matchActive &&
                  state.opponentGamerTag != null &&
                  !state.isPracticeMode)
                BattleBar(state: state),

              // ── Main content ──
              Expanded(
                child: isMobile
                    ? _MobileLayout(state: state)
                    : _DesktopLayout(state: state),
              ),
            ],
          ),

          // ── Event toast overlay (top-right) ──
          if (state.matchActive && !_showIntro) const EventToast(),

          // ── Phase banner (slides down on phase transitions) ──
          if (state.matchActive && !_showIntro) const PhaseBanner(),

          // ── Floating chat bubble (non-practice, active match) ──
          if (state.matchActive && !state.isPracticeMode && !_showIntro)
            _FloatingChat(
              isOpen: _chatOpen,
              onToggle: () => setState(() => _chatOpen = !_chatOpen),
            ),

          // ── Match intro overlay (3-2-1 FIGHT) ──
          if (_showIntro)
            Positioned.fill(
              child: MatchIntroOverlay(
                opponentTag: state.opponentGamerTag,
                durationSeconds: widget.durationSeconds,
                betAmount: widget.betAmount,
                onComplete: () {
                  if (mounted) setState(() => _showIntro = false);
                },
              ),
            ),

          // ── Match result overlay ──
          if (showOverlay)
            Positioned.fill(
              child: MatchResultOverlay(
                state: state,
                betAmount: widget.betAmount,
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Desktop Layout — 2 columns: Chart+Positions | Order
// =============================================================================

class _DesktopLayout extends StatelessWidget {
  final TradingState state;

  const _DesktopLayout({required this.state});

  @override
  Widget build(BuildContext context) {
    final orderW = Responsive.value<double>(context,
        mobile: 340, tablet: 300, desktop: 340);
    final positionsH = Responsive.value<double>(context,
        mobile: 180, tablet: 180, desktop: 220);

    return Row(
      children: [
        // ── Chart + Positions column ──
        Expanded(
          flex: 3,
          child: Column(
            children: [
              AssetBar(state: state),
              const ChartToolbar(),
              const Expanded(child: LWChart()),
              Container(height: 1, color: AppTheme.border),
              SizedBox(
                height: positionsH,
                child: PositionsPanel(state: state),
              ),
            ],
          ),
        ),

        Container(width: 1, color: AppTheme.border),

        // ── Order panel ──
        SizedBox(
          width: orderW,
          child: OrderPanel(state: state),
        ),
      ],
    );
  }
}

// =============================================================================
// Floating Chat — bubble + expandable overlay panel
// =============================================================================

class _FloatingChat extends ConsumerStatefulWidget {
  final bool isOpen;
  final VoidCallback onToggle;

  const _FloatingChat({required this.isOpen, required this.onToggle});

  @override
  ConsumerState<_FloatingChat> createState() => _FloatingChatState();
}

class _FloatingChatState extends ConsumerState<_FloatingChat>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale;
  late Animation<double> _fade;
  int _lastSeenCount = 0;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutBack),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOut),
    );
    if (widget.isOpen) _anim.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant _FloatingChat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen && !oldWidget.isOpen) {
      _anim.forward();
      // Mark messages as seen when opening.
      _lastSeenCount = ref.read(matchChatProvider).length;
    } else if (!widget.isOpen && oldWidget.isOpen) {
      _anim.reverse();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(matchChatProvider);
    final unread = widget.isOpen ? 0 : (messages.length - _lastSeenCount).clamp(0, 99);
    final isMobile = Responsive.isMobile(context);
    final panelW = isMobile ? 280.0 : 320.0;
    final panelH = isMobile ? 360.0 : 420.0;

    return Positioned(
      bottom: 16,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Expanded chat panel ──
          SizeTransition(
            sizeFactor: _fade,
            axisAlignment: 1.0,
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                alignment: Alignment.bottomRight,
                child: Container(
                  width: panelW,
                  height: panelH,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: MatchChatPanel(
                    onClose: widget.onToggle,
                  ),
                ),
              ),
            ),
          ),

          // ── Chat bubble button ──
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onToggle,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.isOpen
                      ? AppTheme.solanaPurple
                      : AppTheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.isOpen
                        ? AppTheme.solanaPurple
                        : AppTheme.border,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (widget.isOpen
                              ? AppTheme.solanaPurple
                              : Colors.black)
                          .withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      widget.isOpen
                          ? Icons.close_rounded
                          : Icons.chat_bubble_outline_rounded,
                      size: 20,
                      color: widget.isOpen
                          ? Colors.white
                          : AppTheme.textSecondary,
                    ),
                    // Unread badge.
                    if (unread > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppTheme.error,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.surface,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Mobile Layout — 2 tabs: Trade | Ops
// =============================================================================

class _MobileLayout extends StatelessWidget {
  final TradingState state;

  const _MobileLayout({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AssetBar(state: state),
        const ChartToolbar(),
        const Expanded(flex: 5, child: LWChart()),
        Container(height: 1, color: AppTheme.border),
        Expanded(
          flex: 7,
          child: DefaultTabController(
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
                    labelStyle: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600),
                    tabs: const [
                      Tab(text: 'Trade'),
                      Tab(text: 'Ops'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(
                        padding:
                            const EdgeInsets.only(bottom: 24),
                        child: OrderPanel(state: state),
                      ),
                      PositionsPanel(state: state),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
