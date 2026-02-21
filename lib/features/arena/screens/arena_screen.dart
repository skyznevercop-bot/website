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
                chatOpen: _chatOpen,
                onChatToggle: () =>
                    setState(() => _chatOpen = !_chatOpen),
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
                    : _DesktopLayout(
                        state: state,
                        chatOpen: _chatOpen,
                        onChatClose: () =>
                            setState(() => _chatOpen = false),
                      ),
              ),
            ],
          ),

          // ── Event toast overlay (top-right) ──
          if (state.matchActive && !_showIntro) const EventToast(),

          // ── Phase banner (slides down on phase transitions) ──
          if (state.matchActive && !_showIntro) const PhaseBanner(),

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
// Desktop Layout — 3 columns: Chart+Positions | Order | Events/Chat
// =============================================================================

class _DesktopLayout extends StatelessWidget {
  final TradingState state;
  final bool chatOpen;
  final VoidCallback onChatClose;

  const _DesktopLayout({
    required this.state,
    required this.chatOpen,
    required this.onChatClose,
  });

  @override
  Widget build(BuildContext context) {
    final orderW = Responsive.value<double>(context,
        mobile: 340, tablet: 300, desktop: 340);
    final sidebarW = Responsive.value<double>(context,
        mobile: 300, tablet: 260, desktop: 300);
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

        // ── Sidebar: Events / Chat (tabbed) ──
        if (chatOpen) ...[
          Container(width: 1, color: AppTheme.border),
          SizedBox(
            width: sidebarW,
            child: _SidebarPanel(onClose: onChatClose),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// Sidebar Panel — Tabbed Events | Chat
// =============================================================================

class _SidebarPanel extends StatefulWidget {
  final VoidCallback onClose;

  const _SidebarPanel({required this.onClose});

  @override
  State<_SidebarPanel> createState() => _SidebarPanelState();
}

class _SidebarPanelState extends State<_SidebarPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: Column(
        children: [
          // Tab header.
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.solanaPurple,
                    unselectedLabelColor: AppTheme.textTertiary,
                    indicatorColor: AppTheme.solanaPurple,
                    indicatorWeight: 2,
                    dividerHeight: 0,
                    labelStyle: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600),
                    tabs: const [
                      Tab(text: 'Events'),
                      Tab(text: 'Chat'),
                    ],
                  ),
                ),
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

          // Tab content.
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                EventFeedPanel(),
                MatchChatPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Mobile Layout — 4 tabs: Trade | Ops | Feed | Chat
// =============================================================================

class _MobileLayout extends StatelessWidget {
  final TradingState state;

  const _MobileLayout({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AssetBar(state: state),
        const Expanded(flex: 5, child: LWChart()),
        Container(height: 1, color: AppTheme.border),
        Expanded(
          flex: 7,
          child: DefaultTabController(
            length: 4,
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
                      Tab(text: 'Feed'),
                      Tab(text: 'Chat'),
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
                      const EventFeedPanel(),
                      const MatchChatPanel(),
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
