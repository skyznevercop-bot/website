import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/environment.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../features/arena/providers/trading_provider.dart';
import '../../../features/wallet/models/wallet_state.dart';
import '../../../features/wallet/providers/wallet_provider.dart';
import '../../../features/wallet/widgets/connect_wallet_modal.dart';
import '../../../features/onboarding/providers/onboarding_provider.dart';
import '../../../features/onboarding/widgets/onboarding_keys.dart';
import '../../../features/friends/models/friend_models.dart';
import '../../../features/friends/providers/friend_provider.dart';
import '../providers/queue_provider.dart';

// =============================================================================
// Play Screen — "War Room" lobby (v2: chip selectors, player card, face-off)
// =============================================================================

class PlayScreen extends ConsumerWidget {
  const PlayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trading = ref.watch(tradingProvider);

    return Padding(
      padding: Responsive.horizontalPadding(context).copyWith(
        top: 24,
        bottom: 24,
      ),
      child: Responsive.isDesktop(context)
          ? Column(
              children: [
                if (trading.matchActive) _ActiveMatchBanner(state: trading),
                const Expanded(child: _ArenaCard()),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  if (trading.matchActive) _ActiveMatchBanner(state: trading),
                  const _ArenaCard(),
                ],
              ),
            ),
    );
  }
}

// =============================================================================
// Active Match Banner
// =============================================================================

class _ActiveMatchBanner extends StatelessWidget {
  final TradingState state;
  const _ActiveMatchBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    final oppTag = state.opponentGamerTag ?? 'Opponent';
    final route = state.arenaRoute;
    final m = state.matchTimeRemainingSeconds ~/ 60;
    final s = state.matchTimeRemainingSeconds % 60;
    final timeStr =
        '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: MouseRegion(
        cursor: route != null ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          onTap: route != null ? () => GoRouter.of(context).go(route) : null,
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppTheme.solanaPurple.withValues(alpha: 0.2),
                AppTheme.solanaPurple.withValues(alpha: 0.08),
              ]),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                  color: AppTheme.solanaPurple.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppTheme.solanaGreen,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.solanaGreen.withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Match in Progress',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      const SizedBox(height: 2),
                      Text('VS $oppTag  •  $timeStr remaining',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.white60),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.solanaPurple,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Return to Arena',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Arena Card — Main lobby card
// =============================================================================

class _ArenaCard extends ConsumerStatefulWidget {
  const _ArenaCard();

  @override
  ConsumerState<_ArenaCard> createState() => _ArenaCardState();
}

class _ArenaCardState extends ConsumerState<_ArenaCard> {
  int _selectedDuration = 0;
  int _selectedBet = AppConstants.defaultBetIndex;

  // Onboarding keys.
  final _heroKey = GlobalKey(debugLabel: 'onboarding_hero');
  final _durationWheelKey = GlobalKey(debugLabel: 'onboarding_duration');
  final _betAmountWheelKey = GlobalKey(debugLabel: 'onboarding_betAmount');
  final _matchInfoRowKey = GlobalKey(debugLabel: 'onboarding_matchInfo');
  final _connectWalletButtonKey =
      GlobalKey(debugLabel: 'onboarding_connectWallet');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(onboardingKeysProvider.notifier).setKeys(
            OnboardingTargetKeys(
              heroKey: _heroKey,
              durationWheelKey: _durationWheelKey,
              betAmountWheelKey: _betAmountWheelKey,
              matchInfoRowKey: _matchInfoRowKey,
              connectWalletButtonKey: _connectWalletButtonKey,
            ),
          );
      ref.read(queueProvider.notifier).init();
      final wallet = ref.read(walletProvider);
      if (wallet.isConnected && wallet.address != null) {
        ref.read(queueProvider.notifier).fetchUserStats(wallet.address!);
      }
    });
  }

  @override
  void deactivate() {
    final keysNotifier = ref.read(onboardingKeysProvider.notifier);
    final queueNotifier = ref.read(queueProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        keysNotifier.clear();
        queueNotifier.dispose();
      }
    });
    super.deactivate();
  }

  int get _betAmount => AppConstants.betAmounts[_selectedBet];
  QueueDuration get _selected => AppConstants.durations[_selectedDuration];

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final queue = ref.watch(queueProvider);

    // match_found listener is now global in AppShell — no duplicate here.

    // Fetch user stats when wallet connects.
    ref.listen<WalletState>(walletProvider, (prev, next) {
      if (next.isConnected &&
          !(prev?.isConnected ?? false) &&
          next.address != null) {
        ref.read(queueProvider.notifier).fetchUserStats(next.address!);
      }
    });

    // Friend challenge accept/decline feedback.
    ref.listen<FriendsState>(friendProvider, (prev, next) {
      if (next.successMessage != null &&
          next.successMessage != prev?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!,
                style: GoogleFonts.inter(fontSize: 13)),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(friendProvider.notifier).clearMessages();
      }
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!,
                style: GoogleFonts.inter(fontSize: 13)),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(friendProvider.notifier).clearMessages();
      }
    });

    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppTheme.solanaPurple.withValues(alpha: 0.15),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Responsive.isDesktop(context)
          ? _buildDesktopLayout(wallet, queue)
          : _buildMobileLayout(wallet, queue),
    );
  }

  // ── Desktop: 2 columns ──

  Widget _buildDesktopLayout(WalletState wallet, QueueState queue) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left: Hero + Player Card + Live Matches.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KeyedSubtree(
                    key: _heroKey,
                    child: _buildHeroContent(queue)),
                const SizedBox(height: 28),
                _PlayerIdentityCard(wallet: wallet, queue: queue),
                const SizedBox(height: 12),
                Expanded(child: _TabbedFeed(queue: queue)),
              ],
            ),
          ),
        ),
        Container(
          width: 1,
          margin: const EdgeInsets.symmetric(vertical: 32),
          color: Colors.white.withValues(alpha: 0.08),
        ),
        // Right: Pickers + Queue.
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(40),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 80,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section header matching the left side's visual weight.
                      Text(
                        'Match Setup',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choose your match duration and bet amount.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white38,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _buildPickerContent(wallet, queue),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Mobile: single column ──

  Widget _buildMobileLayout(WalletState wallet, QueueState queue) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          KeyedSubtree(
              key: _heroKey,
              child: _buildHeroContent(queue, isMobile: true)),
          const SizedBox(height: 20),
          _PlayerIdentityCard(wallet: wallet, queue: queue),
          const SizedBox(height: 20),
          Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 20),
          _buildPickerContent(wallet, queue, isMobile: true),
        ],
      ),
    );
  }

  // ── Hero Content ──

  Widget _buildHeroContent(QueueState queue, {bool isMobile = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live + Beta badges.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.solanaGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppTheme.solanaGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: AppTheme.solanaGreen, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    Environment.useDevnet
                        ? 'LIVE ON DEVNET'
                        : 'LIVE ON MAINNET',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.solanaGreen,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.solanaPurple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppTheme.solanaPurple.withValues(alpha: 0.3)),
              ),
              child: Text(
                'BETA',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.solanaPurple,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Title.
        Text(
          'Enter the Arena',
          style: GoogleFonts.inter(
            fontSize: isMobile ? 28 : 38,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 14),

        // Subtitle.
        Text(
          'Go head-to-head in 1v1 trading battles. Deposit USDC, '
          'pick a duration, and outperform your opponent to win the pot.',
          style: GoogleFonts.inter(
            fontSize: isMobile ? 13 : 15,
            color: Colors.white60,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 24),

        // Platform stats.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              _HeroStat(
                value: queue.totalPlayers > 0
                    ? _fmtNum(queue.totalPlayers)
                    : '--',
                label: 'Players',
              ),
              const SizedBox(width: 32),
              _HeroStat(
                value: queue.totalMatches > 0
                    ? _fmtNum(queue.totalMatches)
                    : '--',
                label: 'Matches',
              ),
              const SizedBox(width: 32),
              _HeroStat(
                value: queue.totalVolume > 0
                    ? _fmtVolume(queue.totalVolume)
                    : '--',
                label: 'Volume',
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _fmtNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  static String _fmtVolume(double v) {
    if (v >= 1000000) return '\$${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '\$${(v / 1000).toStringAsFixed(1)}K';
    return '\$${v.toStringAsFixed(0)}';
  }

  // ── Picker Content ──

  Widget _buildPickerContent(WalletState wallet, QueueState queue,
      {bool isMobile = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Duration chips.
        KeyedSubtree(
          key: _durationWheelKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('DURATION'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(AppConstants.durations.length, (i) {
                  final dur = AppConstants.durations[i];
                  final count = queue.queueSizes[i];
                  return _ChipButton(
                    label: dur.label,
                    badge: count > 0 ? '$count' : null,
                    isSelected: _selectedDuration == i,
                    onTap: () =>
                        setState(() => _selectedDuration = i),
                  );
                }),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Bet amount chips.
        KeyedSubtree(
          key: _betAmountWheelKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('BET AMOUNT'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    List.generate(AppConstants.betAmounts.length, (i) {
                  return _ChipButton(
                    label: '\$${AppConstants.betAmounts[i]}',
                    isSelected: _selectedBet == i,
                    onTap: () => setState(() => _selectedBet = i),
                  );
                }),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Match info row.
        Container(
          key: _matchInfoRowKey,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Row(
            children: [
              Expanded(
                child: _InfoTile(
                  icon: Icons.emoji_events_rounded,
                  label: 'Pot Size',
                  value: '\$${_betAmount * 2}',
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              Expanded(
                child: _InfoTile(
                  icon: Icons.timer_outlined,
                  label: 'Duration',
                  value: _selected.label,
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              Expanded(
                child: _InfoTile(
                  icon: Icons.leaderboard_rounded,
                  label: 'Your Rank',
                  value: queue.userRank != null
                      ? '#${queue.userRank}'
                      : '--',
                ),
              ),
            ],
          ),
        ),

        // Separator before action area.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),

        // Connect wallet.
        _HighlightWalletButton(
          globalKey: _connectWalletButtonKey,
          child: _ConnectWalletButton(
            wallet: wallet,
            onTap: () => showConnectWalletModal(context),
          ),
        ),

        const SizedBox(height: 12),

        // Queue button.
        SizedBox(
          width: double.infinity,
          height: 60,
          child: queue.isInQueue
              ? _SearchingButton(
                  waitSeconds: queue.waitSeconds,
                  onCancel: () =>
                      ref.read(queueProvider.notifier).leaveQueue(),
                )
              : _EnterArenaButton(
                  isConnected: wallet.isConnected,
                  onTap: () {
                    if (!wallet.isConnected) {
                      showConnectWalletModal(context);
                      return;
                    }
                    // Check platform balance before joining queue.
                    final bet = _betAmount.toDouble();
                    if (wallet.availableBalance < bet) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Insufficient balance. You need \$${bet.toStringAsFixed(0)} USDC. '
                            'Deposit from your Portfolio page.',
                            style: GoogleFonts.inter(fontSize: 13),
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: const Color(0xFFE53E3E),
                          duration: const Duration(seconds: 4),
                        ),
                      );
                      return;
                    }
                    ref.read(queueProvider.notifier).joinQueue(
                          durationIndex: _selectedDuration,
                          durationLabel: _selected.label,
                          betAmount: bet,
                        );
                  },
                ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Colors.white38,
        letterSpacing: 2,
      ),
    );
  }
}

// =============================================================================
// Chip Button — for duration and bet selection
// =============================================================================

class _ChipButton extends StatefulWidget {
  final String label;
  final String? badge;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChipButton({
    required this.label,
    this.badge,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ChipButton> createState() => _ChipButtonState();
}

class _ChipButtonState extends State<_ChipButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppTheme.solanaPurple.withValues(alpha: 0.2)
                : _hovered
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isSelected
                  ? AppTheme.solanaPurple.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.08),
              width: widget.isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight:
                      widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: widget.isSelected ? Colors.white : Colors.white70,
                ),
              ),
              if (widget.badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.solanaPurple.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    widget.badge!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.solanaPurple,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Player Identity Card
// =============================================================================

class _PlayerIdentityCard extends StatelessWidget {
  final WalletState wallet;
  final QueueState queue;

  const _PlayerIdentityCard({required this.wallet, required this.queue});

  @override
  Widget build(BuildContext context) {
    if (!wallet.isConnected) return const SizedBox.shrink();

    final tag = wallet.gamerTag ?? 'Player';
    final wins = queue.userWins;
    final losses = queue.userLosses;
    final total = wins + losses;
    final winRate = total > 0 ? (wins / total) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          // Avatar.
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.solanaPurple.withValues(alpha: 0.15),
              border: Border.all(
                  color: AppTheme.solanaPurple.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                tag.substring(0, 2).toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.solanaPurple,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Tag + record.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tag,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(height: 4),
                if (total > 0) ...[
                  // Win/loss bar.
                  SizedBox(
                    height: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Row(
                        children: [
                          Flexible(
                            flex: (winRate * 100).round().clamp(1, 100),
                            child: Container(color: AppTheme.solanaGreen),
                          ),
                          Flexible(
                            flex:
                                ((1 - winRate) * 100).round().clamp(1, 100),
                            child: Container(color: AppTheme.error),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${wins}W - ${losses}L  •  ${(winRate * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: Colors.white38),
                  ),
                ] else
                  Text('No matches yet',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: Colors.white38)),
              ],
            ),
          ),

          // PnL.
          if (total > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${queue.userPnl >= 0 ? '+' : ''}\$${queue.userPnl.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: queue.userPnl >= 0
                        ? AppTheme.solanaGreen
                        : AppTheme.error,
                  ),
                ),
                Text('Total PnL',
                    style: GoogleFonts.inter(
                        fontSize: 10, color: Colors.white38)),
              ],
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Tabbed Feed — Live / Challenges / Recent (swappable)
// =============================================================================

enum _FeedTab { live, challenges, recent }

class _TabbedFeed extends ConsumerStatefulWidget {
  final QueueState queue;
  const _TabbedFeed({required this.queue});

  @override
  ConsumerState<_TabbedFeed> createState() => _TabbedFeedState();
}

class _TabbedFeedState extends ConsumerState<_TabbedFeed> {
  _FeedTab _activeTab = _FeedTab.live;

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendProvider);
    final challengeCount =
        friends.receivedChallenges.length + friends.sentChallenges.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab bar.
          Row(
            children: [
              _TabChip(
                label: 'Live',
                isActive: _activeTab == _FeedTab.live,
                onTap: () => setState(() => _activeTab = _FeedTab.live),
                badge: widget.queue.liveMatches.isNotEmpty
                    ? '${widget.queue.liveMatches.length}'
                    : null,
                badgeColor: AppTheme.solanaGreen,
              ),
              const SizedBox(width: 6),
              _TabChip(
                label: 'Challenges',
                isActive: _activeTab == _FeedTab.challenges,
                onTap: () => setState(() => _activeTab = _FeedTab.challenges),
                badge: challengeCount > 0 ? '$challengeCount' : null,
                badgeColor: AppTheme.error,
              ),
              const SizedBox(width: 6),
              _TabChip(
                label: 'Recent',
                isActive: _activeTab == _FeedTab.recent,
                onTap: () => setState(() => _activeTab = _FeedTab.recent),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Tab content.
          Expanded(
            child: switch (_activeTab) {
              _FeedTab.live => _LiveContent(
                  matches: widget.queue.liveMatches),
              _FeedTab.challenges => _ChallengesContent(
                  received: friends.receivedChallenges,
                  sent: friends.sentChallenges),
              _FeedTab.recent => _RecentContent(
                  results: widget.queue.recentMatches),
            },
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final String? badge;
  final Color? badgeColor;

  const _TabChip({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badge,
    this.badgeColor,
  });

  @override
  State<_TabChip> createState() => _TabChipState();
}

class _TabChipState extends State<_TabChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppTheme.solanaPurple.withValues(alpha: 0.2)
                : _hovered
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isActive
                  ? AppTheme.solanaPurple.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight:
                      widget.isActive ? FontWeight.w700 : FontWeight.w500,
                  color: widget.isActive ? Colors.white : Colors.white54,
                ),
              ),
              if (widget.badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: widget.badgeColor ?? AppTheme.solanaPurple,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.badge!,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Live Content ──

class _LiveContent extends StatelessWidget {
  final List<LiveMatch> matches;
  const _LiveContent({required this.matches});

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return Center(
        child: Text('No active matches right now',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white38)),
      );
    }
    return ListView.separated(
      itemCount: matches.length,
      separatorBuilder: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Container(
            height: 1, color: Colors.white.withValues(alpha: 0.06)),
      ),
      itemBuilder: (_, i) => _MatchRow(match: matches[i]),
    );
  }
}

class _MatchRow extends StatelessWidget {
  final LiveMatch match;
  const _MatchRow({required this.match});

  String _timeRemaining() {
    if (match.endTime == null) return match.duration;
    final remaining = match.endTime! - DateTime.now().millisecondsSinceEpoch;
    if (remaining <= 0) return 'Ending...';
    final minutes = remaining ~/ 60000;
    final seconds = (remaining % 60000) ~/ 1000;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}h ${mins}m';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 28,
          decoration: BoxDecoration(
            color:
                match.player1Leading ? AppTheme.solanaGreen : AppTheme.error,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(match.player1,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: match.player1Leading
                    ? AppTheme.solanaGreen
                    : Colors.white70,
              ),
              overflow: TextOverflow.ellipsis),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.solanaPurple.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${match.bet > 0 ? '\$${match.bet.toStringAsFixed(0)} · ' : ''}${_timeRemaining()}',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white54,
            ),
          ),
        ),
        Expanded(
          child: Text(match.player2,
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: match.player1Leading
                    ? Colors.white70
                    : AppTheme.solanaGreen,
              ),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

// ── Challenges Content ──

class _ChallengesContent extends ConsumerWidget {
  final List<Challenge> received;
  final List<Challenge> sent;
  const _ChallengesContent({required this.received, required this.sent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (received.isEmpty && sent.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sports_esports_outlined,
                size: 32, color: Colors.white24),
            const SizedBox(height: 8),
            Text('No pending challenges',
                style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.white38)),
          ],
        ),
      );
    }
    final items = <Widget>[
      ...received.map((c) => _ChallengeRow(challenge: c, isReceived: true)),
      ...sent.map((c) => _ChallengeRow(challenge: c, isReceived: false)),
    ];
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => items[i],
    );
  }
}

class _ChallengeRow extends ConsumerWidget {
  final Challenge challenge;
  final bool isReceived;
  const _ChallengeRow({required this.challenge, required this.isReceived});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tag = isReceived
        ? (challenge.fromGamerTag ??
            '${challenge.from.substring(0, 4)}...${challenge.from.substring(challenge.from.length - 4)}')
        : (challenge.toGamerTag ??
            '${challenge.to.substring(0, 4)}...${challenge.to.substring(challenge.to.length - 4)}');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isReceived
            ? AppTheme.solanaPurple.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isReceived
                ? AppTheme.solanaPurple.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    isReceived ? '$tag challenges you!' : 'Waiting for $tag...',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                    '${challenge.duration} · \$${challenge.bet.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: Colors.white38)),
              ],
            ),
          ),
          if (isReceived) ...[
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => ref
                    .read(friendProvider.notifier)
                    .acceptChallenge(challenge.id),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.solanaPurple,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Accept',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      )),
                ),
              ),
            ),
            const SizedBox(width: 6),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => ref
                    .read(friendProvider.notifier)
                    .declineChallenge(challenge.id),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 14, color: Colors.white38),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Pending',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warning,
                  )),
            ),
            const SizedBox(width: 6),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => ref
                    .read(friendProvider.notifier)
                    .cancelChallenge(challenge.id),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 14, color: Colors.white38),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Recent Content ──

class _RecentContent extends StatelessWidget {
  final List<RecentMatchResult> results;
  const _RecentContent({required this.results});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history_rounded,
                size: 32, color: Colors.white24),
            const SizedBox(height: 8),
            Text('No matches yet',
                style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.white38)),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (_, i) => _RecentRow(result: results[i]),
    );
  }
}

class _RecentRow extends StatelessWidget {
  final RecentMatchResult result;
  const _RecentRow({required this.result});

  @override
  Widget build(BuildContext context) {
    final Color resultColor;
    final Color resultBg;
    final String label;
    switch (result.result) {
      case 'WIN':
        resultColor = AppTheme.solanaGreen;
        resultBg = AppTheme.solanaGreen.withValues(alpha: 0.12);
        label = 'W';
      case 'LOSS':
        resultColor = AppTheme.error;
        resultBg = AppTheme.error.withValues(alpha: 0.12);
        label = 'L';
      default:
        resultColor = AppTheme.warning;
        resultBg = AppTheme.warning.withValues(alpha: 0.12);
        label = 'T';
    }

    return Row(
      children: [
        Container(
          width: 26,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: resultBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: resultColor,
                )),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'vs ${result.opponentGamerTag}',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '${result.pnl >= 0 ? '+' : ''}\$${result.pnl.toStringAsFixed(2)}',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: result.pnl >= 0 ? AppTheme.solanaGreen : AppTheme.error,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Enter Arena Button — main CTA
// =============================================================================

class _EnterArenaButton extends StatefulWidget {
  final bool isConnected;
  final VoidCallback onTap;
  const _EnterArenaButton({required this.isConnected, required this.onTap});

  @override
  State<_EnterArenaButton> createState() => _EnterArenaButtonState();
}

class _EnterArenaButtonState extends State<_EnterArenaButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: widget.isConnected
                ? (_hovered
                    ? const LinearGradient(colors: [
                        AppTheme.solanaPurpleDark,
                        AppTheme.solanaPurple,
                      ])
                    : AppTheme.purpleGradient)
                : LinearGradient(colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.04),
                  ]),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: widget.isConnected
                ? null
                : Border.all(
                    color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: _hovered && widget.isConnected
                ? [
                    BoxShadow(
                      color:
                          AppTheme.solanaPurple.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isConnected)
                  const Icon(Icons.bolt_rounded,
                      size: 26, color: Colors.white),
                if (widget.isConnected) const SizedBox(width: 10),
                Text(
                  widget.isConnected
                      ? 'ENTER THE ARENA'
                      : 'Connect Wallet to Play',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: widget.isConnected ? 1.5 : 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Searching Button — pulsing queue animation
// =============================================================================

class _SearchingButton extends StatefulWidget {
  final int waitSeconds;
  final VoidCallback onCancel;
  const _SearchingButton(
      {required this.waitSeconds, required this.onCancel});

  @override
  State<_SearchingButton> createState() => _SearchingButtonState();
}

class _SearchingButtonState extends State<_SearchingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final waitStr = widget.waitSeconds < 60
        ? '${widget.waitSeconds}s'
        : '${widget.waitSeconds ~/ 60}:${(widget.waitSeconds % 60).toString().padLeft(2, '0')}';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onCancel,
        child: AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (context, child) {
            final glow = 0.15 + _pulseCtrl.value * 0.15;
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppTheme.solanaPurple.withValues(alpha: 0.3),
                  AppTheme.solanaPurple.withValues(alpha: 0.15),
                ]),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                    color: AppTheme.solanaPurple.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.solanaPurple.withValues(alpha: glow),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white70),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Searching for opponent... $waitStr',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _hovered
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Cancel',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      )),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Supporting Widgets
// =============================================================================

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  const _HeroStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        const SizedBox(height: 2),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white38)),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final double? iconSize;
  final Color? iconColor;
  final String label;
  final String value;
  const _InfoTile(
      {required this.icon, this.iconSize, this.iconColor, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: iconSize ?? 22, color: iconColor ?? Colors.white38),
        const SizedBox(height: 6),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        const SizedBox(height: 2),
        Text(label,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white38)),
      ],
    );
  }
}

class _ConnectWalletButton extends StatefulWidget {
  final WalletState wallet;
  final VoidCallback onTap;
  const _ConnectWalletButton({required this.wallet, required this.onTap});

  @override
  State<_ConnectWalletButton> createState() => _ConnectWalletButtonState();
}

class _ConnectWalletButtonState extends State<_ConnectWalletButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final connected = widget.wallet.isConnected;
    final balance = widget.wallet.platformBalance;
    final needsDeposit = connected && balance < 1;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: !connected
            ? widget.onTap
            : needsDeposit
                ? () => GoRouter.of(context).go(AppConstants.portfolioRoute)
                : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: needsDeposit
                ? _hovered
                    ? AppTheme.solanaPurple.withValues(alpha: 0.2)
                    : AppTheme.solanaPurple.withValues(alpha: 0.1)
                : connected
                    ? _hovered
                        ? AppTheme.solanaGreen.withValues(alpha: 0.15)
                        : AppTheme.solanaGreen.withValues(alpha: 0.08)
                    : _hovered
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: needsDeposit
                  ? AppTheme.solanaPurple
                      .withValues(alpha: _hovered ? 0.5 : 0.3)
                  : connected
                      ? AppTheme.solanaGreen
                          .withValues(alpha: _hovered ? 0.4 : 0.2)
                      : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: SizedBox(
            height: 60,
            child: connected
                ? needsDeposit
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_rounded,
                              size: 20, color: AppTheme.info),
                          const SizedBox(width: 4),
                          Text(
                            'Deposit',
                            style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '\$${balance.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.solanaGreen),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'USDC',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.white38),
                          ),
                        ],
                      )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded,
                          size: 24, color: Colors.white54),
                      const SizedBox(width: 10),
                      Text('Connect Wallet',
                          style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _HighlightWalletButton extends ConsumerStatefulWidget {
  final GlobalKey globalKey;
  final Widget child;
  const _HighlightWalletButton(
      {required this.globalKey, required this.child});

  @override
  ConsumerState<_HighlightWalletButton> createState() =>
      _HighlightWalletButtonState();
}

class _HighlightWalletButtonState
    extends ConsumerState<_HighlightWalletButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  bool _isHighlighting = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    final notifier = ref.read(onboardingProvider.notifier);
    ref.listenManual(
      onboardingProvider.select((s) => s.highlightWallet),
      (previous, next) {
        if (next && !_isHighlighting) {
          _isHighlighting = true;
          _pulseController.repeat(reverse: true);
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) {
              _pulseController.stop();
              _pulseController.reset();
              _isHighlighting = false;
              notifier.clearHighlight();
            }
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final highlight = ref.watch(
      onboardingProvider.select((s) => s.highlightWallet),
    );

    return SizedBox(
      key: widget.globalKey,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            decoration: highlight
                ? BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMd),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.solanaPurple.withValues(
                            alpha: 0.2 + _pulseAnimation.value * 0.4),
                        blurRadius: 12 + _pulseAnimation.value * 12,
                        spreadRadius: _pulseAnimation.value * 4,
                      ),
                    ],
                  )
                : null,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
