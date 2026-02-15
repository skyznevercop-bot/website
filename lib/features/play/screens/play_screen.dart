import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/environment.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/escrow_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../features/arena/providers/trading_provider.dart';
import '../../../features/wallet/models/wallet_state.dart';
import '../../../features/wallet/providers/wallet_provider.dart';
import '../../../features/wallet/widgets/connect_wallet_modal.dart';
import '../../../features/onboarding/providers/onboarding_provider.dart';
import '../../../features/onboarding/widgets/onboarding_keys.dart';
import '../providers/queue_provider.dart';

/// The main Play screen — unified arena card followed by live activity section.
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

// ═══════════════════════════════════════════════════════════════════════════════
// Active Match Banner — shown when user has a match in progress
// ═══════════════════════════════════════════════════════════════════════════════

class _ActiveMatchBanner extends StatelessWidget {
  final TradingState state;
  const _ActiveMatchBanner({required this.state});

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final oppTag = state.opponentGamerTag ?? 'Opponent';
    final route = state.arenaRoute;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: MouseRegion(
        cursor: route != null ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          onTap: route != null ? () => GoRouter.of(context).go(route) : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.solanaPurple.withValues(alpha: 0.2),
                  AppTheme.solanaPurple.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: AppTheme.solanaPurple.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                // Pulsing dot
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
                // Match info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Match in Progress',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'VS $oppTag  •  ${_formatTime(state.matchTimeRemainingSeconds)} remaining',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                // Return button
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.solanaPurple,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Return to Arena',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
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

// ═══════════════════════════════════════════════════════════════════════════════
// Unified Arena Card — hero + timeframe picker in one card
// ═══════════════════════════════════════════════════════════════════════════════

class _ArenaCard extends ConsumerStatefulWidget {
  const _ArenaCard();

  @override
  ConsumerState<_ArenaCard> createState() => _ArenaCardState();
}

class _ArenaCardState extends ConsumerState<_ArenaCard> {
  late final FixedExtentScrollController _timeframeController;
  late final FixedExtentScrollController _betController;
  int _selectedIndex = 0;
  int _betIndex = 3; // default $10

  static const _betAmounts = [1, 2, 5, 10, 25, 50, 100];

  // Onboarding target keys
  final _heroKey = GlobalKey(debugLabel: 'onboarding_hero');
  final _timeframeWheelKey = GlobalKey(debugLabel: 'onboarding_timeframe');
  final _betAmountWheelKey = GlobalKey(debugLabel: 'onboarding_betAmount');
  final _matchInfoRowKey = GlobalKey(debugLabel: 'onboarding_matchInfo');
  final _connectWalletButtonKey = GlobalKey(debugLabel: 'onboarding_connectWallet');

  @override
  void initState() {
    super.initState();
    _timeframeController =
        FixedExtentScrollController(initialItem: _selectedIndex);
    _betController = FixedExtentScrollController(initialItem: _betIndex);

    // Register keys with onboarding provider after first layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(onboardingKeysProvider.notifier).setKeys(
            OnboardingTargetKeys(
              heroKey: _heroKey,
              timeframeWheelKey: _timeframeWheelKey,
              betAmountWheelKey: _betAmountWheelKey,
              matchInfoRowKey: _matchInfoRowKey,
              connectWalletButtonKey: _connectWalletButtonKey,
            ),
          );

      // Initialize the queue provider for live data.
      ref.read(queueProvider.notifier).init();

      // Fetch user stats if connected.
      final wallet = ref.read(walletProvider);
      if (wallet.isConnected && wallet.address != null) {
        ref.read(queueProvider.notifier).fetchUserStats(wallet.address!);
      }
    });
  }

  @override
  void deactivate() {
    // Capture notifier before deferring — ref is invalid after dispose
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

  @override
  void dispose() {
    _timeframeController.dispose();
    _betController.dispose();
    super.dispose();
  }

  int get _betAmount => _betAmounts[_betIndex];
  QueueTimeframe get _selected => AppConstants.timeframes[_selectedIndex];

  void _showMatchFoundDialog(BuildContext context, MatchFoundData match) {
    final durationSec = _selected.duration.inSeconds;
    final now = DateTime.now().millisecondsSinceEpoch;
    final wallet = ref.read(walletProvider);
    final walletName = wallet.walletType?.name ?? 'phantom';

    // Dialog state: ready → depositing → confirmed → navigating
    //                   ↘ error (retry goes back to ready)
    String depositState = 'ready';
    String? errorMsg;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void navigateToArena() {
            Navigator.of(ctx).pop();
            context.go(
              Uri(
                path: AppConstants.arenaRoute,
                queryParameters: {
                  'matchId': match.matchId,
                  'd': durationSec.toString(),
                  'bet': match.bet.toString(),
                  'opp': match.opponentAddress,
                  'oppTag': match.opponentGamerTag,
                  'st': now.toString(),
                },
              ).toString(),
            );
          }

          Future<void> onDeposit() async {
            setDialogState(() {
              depositState = 'depositing';
              errorMsg = null;
            });
            try {
              // Step 1: Send USDC on-chain.
              final txSignature = await EscrowService.deposit(
                walletName: walletName,
                amountUsdc: match.bet,
              );
              ref.read(walletProvider.notifier).deductBalance(match.bet);

              // Step 2: Report tx signature to backend for verification.
              setDialogState(() => depositState = 'verifying');
              final api = ApiClient.instance;
              final result = await api.post(
                '/match/${match.matchId}/confirm-deposit',
                {'txSignature': txSignature},
              );

              final matchActive = result['matchActive'] == true;
              if (matchActive) {
                // Both players deposited — go to arena.
                setDialogState(() => depositState = 'confirmed');
                Future.delayed(const Duration(milliseconds: 800), () {
                  if (ctx.mounted) navigateToArena();
                });
              } else {
                // Waiting for opponent to deposit — listen for WS events.
                setDialogState(() => depositState = 'waiting_opponent');
                final sub = ApiClient.instance.wsStream.listen((data) {
                  if (!ctx.mounted) return;
                  final type = data['type'] as String?;
                  if (type == 'match_activated' &&
                      data['matchId'] == match.matchId) {
                    setDialogState(() => depositState = 'confirmed');
                    Future.delayed(const Duration(milliseconds: 800), () {
                      if (ctx.mounted) navigateToArena();
                    });
                  } else if (type == 'match_cancelled' &&
                      data['matchId'] == match.matchId) {
                    setDialogState(() {
                      depositState = 'error';
                      errorMsg = data['reason'] == 'opponent_no_deposit'
                          ? 'Opponent did not deposit. You have been fully refunded.'
                          : 'Match cancelled.';
                    });
                  }
                });
                // Cancel subscription when dialog is popped.
                Future.doWhile(() async {
                  await Future.delayed(const Duration(milliseconds: 500));
                  if (!ctx.mounted) {
                    sub.cancel();
                    return false;
                  }
                  return true;
                });
              }
            } catch (e) {
              setDialogState(() {
                depositState = 'error';
                errorMsg = e
                    .toString()
                    .replaceAll('Exception: ', '')
                    .replaceAll('Error: ', '');
              });
            }
          }

          // Build action button based on deposit state
          Widget actionButton;
          switch (depositState) {
            case 'depositing':
              actionButton = SizedBox(
                width: double.infinity,
                height: 48,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.solanaPurple.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: AppTheme.solanaPurple.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Approve in Wallet...',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            case 'verifying':
              actionButton = SizedBox(
                width: double.infinity,
                height: 48,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.solanaPurple.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: AppTheme.solanaPurple.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Verifying on-chain...',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            case 'waiting_opponent':
              actionButton = SizedBox(
                width: double.infinity,
                height: 48,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.solanaPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: AppTheme.solanaPurple.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Waiting for opponent to deposit...',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            case 'confirmed':
              actionButton = SizedBox(
                width: double.infinity,
                height: 48,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: AppTheme.success.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 18, color: AppTheme.success),
                      const SizedBox(width: 8),
                      Text(
                        'Deposit Confirmed! Entering Arena...',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.success,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            default: // 'ready' or 'error'
              actionButton = Column(
                children: [
                  if (depositState == 'error' && errorMsg != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(
                          color: AppTheme.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        errorMsg!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.error,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.solanaPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                      onPressed: () => onDeposit(),
                      child: Text(
                        depositState == 'error'
                            ? 'Try Again'
                            : 'Deposit \$${match.bet.toStringAsFixed(0)} & Enter Arena',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
          }

          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            ),
            title: Row(
              children: [
                Icon(Icons.sports_esports_rounded,
                    size: 24, color: AppTheme.solanaPurple),
                const SizedBox(width: 10),
                Text(
                  'Opponent Found!',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAlt,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'VS',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textTertiary,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        match.opponentGamerTag,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${match.opponentAddress.substring(0, 4)}...${match.opponentAddress.substring(match.opponentAddress.length - 4)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _dialogInfoTile(
                          'Bet',
                          '\$${match.bet.toStringAsFixed(0)} USDC'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child:
                          _dialogInfoTile('Duration', _selected.label),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Escrow info
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.solanaPurple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(
                      color: AppTheme.solanaPurple.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_rounded,
                          size: 14,
                          color:
                              AppTheme.solanaPurple.withValues(alpha: 0.8)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your bet is sent to a secure on-chain escrow. '
                          'Winner takes 1.9x. 10% rake to treasury.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [actionButton],
          );
        },
      ),
    );
  }

  Widget _dialogInfoTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Column(
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 10, color: AppTheme.textTertiary)),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final queue = ref.watch(queueProvider);

    // Listen for match found → show confirmation then navigate to arena.
    ref.listen<QueueState>(queueProvider, (prev, next) {
      if (next.matchFound != null && prev?.matchFound == null) {
        final match = next.matchFound!;
        ref.read(queueProvider.notifier).clearMatchFound();
        _showMatchFoundDialog(context, match);
      }
    });

    // Fetch user stats when wallet connects.
    ref.listen<WalletState>(walletProvider, (prev, next) {
      if (next.isConnected && !(prev?.isConnected ?? false) && next.address != null) {
        ref.read(queueProvider.notifier).fetchUserStats(next.address!);
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
      child: Responsive.isDesktop(context) ? _buildDesktopLayout(wallet, queue) : _buildMobileLayout(wallet, queue),
    );
  }

  Widget _buildDesktopLayout(WalletState wallet, QueueState queue) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Left: Hero + Live Activity ────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KeyedSubtree(key: _heroKey, child: _buildHeroContent(queue)),
                const Spacer(),
                _buildStatsSection(wallet, queue),
                const SizedBox(height: 12),
                _buildMatchesSection(queue),
              ],
            ),
          ),
        ),
        // ── Vertical Divider ──────────────────────────────────────────
        Container(
          width: 1,
          margin: const EdgeInsets.symmetric(vertical: 32),
          color: Colors.white.withValues(alpha: 0.08),
        ),
        // ── Right: Picker Controls ────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: _buildPickerContent(wallet, queue),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(WalletState wallet, QueueState queue) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          KeyedSubtree(key: _heroKey, child: _buildHeroContent(queue, isMobile: true)),
          const SizedBox(height: 24),
          _buildStatsSection(wallet, queue),
          const SizedBox(height: 12),
          _buildMatchesSection(queue),
          const SizedBox(height: 24),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 24),
          _buildPickerContent(wallet, queue, isMobile: true),
        ],
      ),
    );
  }

  // ── Hero Content (badge, title, subtitle, stats) ──────────────────────────

  Widget _buildHeroContent(QueueState queue, {bool isMobile = false}) {
    final volumeStr = queue.totalVolume >= 1000
        ? '\$${(queue.totalVolume / 1000).toStringAsFixed(1)}K'
        : '\$${queue.totalVolume.toStringAsFixed(0)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.solanaGreen.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.solanaGreen.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.solanaGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Environment.useDevnet ? 'LIVE ON DEVNET' : 'LIVE ON MAINNET',
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
        const SizedBox(height: 24),

        // Title
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

        // Subtitle
        Text(
          'Go head-to-head in 1v1 trading battles. Deposit USDC, '
          'pick a timeframe, and outperform your opponent to win the pot.',
          style: GoogleFonts.inter(
            fontSize: isMobile ? 13 : 15,
            fontWeight: FontWeight.w400,
            color: Colors.white60,
            height: 1.6,
          ),
        ),

        const SizedBox(height: 24),

        // Quick stats (live from backend)
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              _HeroStat(
                value: queue.totalPlayers > 0
                    ? _formatNumber(queue.totalPlayers)
                    : '--',
                label: 'Players',
              ),
              const SizedBox(width: 32),
              _HeroStat(
                value: queue.totalMatches > 0
                    ? _formatNumber(queue.totalMatches)
                    : '--',
                label: 'Matches',
              ),
              const SizedBox(width: 32),
              _HeroStat(
                value: queue.totalVolume > 0 ? volumeStr : '--',
                label: 'Volume',
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  // ── Picker Content (side-by-side wheels, info, buttons) ────────────────────

  Widget _buildPickerContent(WalletState wallet, QueueState queue,
      {bool isMobile = false}) {
    return Column(
      children: [
        // ── Side-by-side wheels ──────────────────────────────────────
        if (isMobile)
          SizedBox(
            height: 200,
            child: _buildWheelsRow(),
          )
        else
          Expanded(child: _buildWheelsRow()),

        // ── Divider ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),

        // ── Match Info Row ──────────────────────────────────────────
        Container(
          key: _matchInfoRowKey,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
                height: 36,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              Expanded(
                child: _InfoTile(
                  icon: Icons.people_rounded,
                  label: 'In Queue',
                  value: '${queue.queueSizes[_selectedIndex]}',
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              Expanded(
                child: _InfoTile(
                  icon: Icons.schedule_rounded,
                  label: 'Est. Wait',
                  value: queue.waitTimes[_selectedIndex],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Connect Wallet Button ───────────────────────────────────
        _HighlightWalletButton(
          globalKey: _connectWalletButtonKey,
          child: _ConnectWalletButton(
            wallet: wallet,
            onTap: () => showConnectWalletModal(context),
          ),
        ),

        const SizedBox(height: 10),

        // ── Join / Leave Queue Button ─────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 48,
          child: queue.isInQueue
              ? _LeaveQueueButton(
                  waitSeconds: queue.waitSeconds,
                  onTap: () {
                    ref.read(queueProvider.notifier).leaveQueue();
                  },
                )
              : _JoinQueueButton(
                  isConnected: wallet.isConnected,
                  timeframeLabel: _selected.label,
                  betAmount: _betAmount,
                  onTap: () {
                    if (!wallet.isConnected) {
                      showConnectWalletModal(context);
                      return;
                    }
                    ref.read(queueProvider.notifier).joinQueue(
                          timeframeIndex: _selectedIndex,
                          timeframeLabel: _selected.label,
                          betAmount: _betAmount.toDouble(),
                        );
                  },
                ),
        ),
      ],
    );
  }

  // ── Side-by-side wheels row ─────────────────────────────────────────────

  Widget _buildWheelsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Timeframe wheel
        Expanded(
          child: Column(
            key: _timeframeWheelKey,
            children: [
              _buildSectionLabel('TIMEFRAME'),
              const SizedBox(height: 8),
              Expanded(
                child: _buildWheel(
                  controller: _timeframeController,
                  itemCount: AppConstants.timeframes.length,
                  selectedIndex: _selectedIndex,
                  onChanged: (i) => setState(() => _selectedIndex = i),
                  labelBuilder: (i) => AppConstants.timeframes[i].label,
                ),
              ),
            ],
          ),
        ),
        // Vertical divider
        Container(
          width: 1,
          margin: const EdgeInsets.symmetric(vertical: 16),
          color: Colors.white.withValues(alpha: 0.08),
        ),
        // Bet amount wheel
        Expanded(
          child: Column(
            key: _betAmountWheelKey,
            children: [
              _buildSectionLabel('BET AMOUNT'),
              const SizedBox(height: 8),
              Expanded(
                child: _buildWheel(
                  controller: _betController,
                  itemCount: _betAmounts.length,
                  selectedIndex: _betIndex,
                  onChanged: (i) => setState(() => _betIndex = i),
                  labelBuilder: (i) => '\$${_betAmounts[i]}',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Generic scroll wheel ──────────────────────────────────────────────────

  Widget _buildWheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required int selectedIndex,
    required ValueChanged<int> onChanged,
    required String Function(int) labelBuilder,
  }) {
    const fadeColor = Color(0xFF2D1B69);
    const itemExtent = 56.0;

    return Listener(
      // Intercept mouse wheel events so they scroll the wheel, not the page
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          final offset = controller.offset + event.scrollDelta.dy;
          final maxOffset = (itemCount - 1) * itemExtent;
          controller.jumpTo(offset.clamp(0, maxOffset));
        }
      },
      child: GestureDetector(
        // Allow click + drag to scroll the wheel
        onVerticalDragUpdate: (details) {
          final offset = controller.offset - details.delta.dy;
          final maxOffset = (itemCount - 1) * itemExtent;
          controller.jumpTo(offset.clamp(0, maxOffset));
        },
        onVerticalDragEnd: (details) {
          // Snap to nearest item after drag ends
          final targetItem = (controller.offset / itemExtent).round();
          controller.animateToItem(
            targetItem.clamp(0, itemCount - 1),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        },
        child: Stack(
          children: [
            // Selection highlight
            Center(
              child: Container(
                height: 56,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: AppTheme.solanaPurple.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
            // Wheel
            ListWheelScrollView.useDelegate(
              controller: controller,
              itemExtent: itemExtent,
              diameterRatio: 1.4,
              perspective: 0.003,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: onChanged,
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: itemCount,
                builder: (context, index) {
                  final isSelected = index == selectedIndex;
                  return Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: GoogleFonts.inter(
                        fontSize: isSelected ? 26 : 20,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.white38,
                      ),
                      child: Text(labelBuilder(index)),
                    ),
                  );
                },
              ),
            ),
            // Top fade
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 48,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        fadeColor,
                        fadeColor.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Bottom fade
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 48,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        fadeColor,
                        fadeColor.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.white38,
        letterSpacing: 1.5,
      ),
    );
  }

  // ── Stats Section (on gradient) ───────────────────────────────────────────

  Widget _buildStatsSection(WalletState wallet, QueueState queue) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded,
                  size: 18, color: AppTheme.solanaPurple),
              const SizedBox(width: 8),
              Text(
                'Your Stats',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!wallet.isConnected)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Connect wallet to see stats',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
                ),
              ),
            )
          else ...[
            _buildStatRow(
              'Win Rate',
              queue.userGamesPlayed > 0
                  ? '${queue.userWinRate}%'
                  : '--',
              queue.userWinRate >= 50
                  ? AppTheme.solanaGreen
                  : (queue.userGamesPlayed > 0 ? AppTheme.error : null),
            ),
            const SizedBox(height: 10),
            _buildStatRow(
              'Total Games',
              '${queue.userGamesPlayed}',
              null,
            ),
            const SizedBox(height: 10),
            _buildStatRow(
              'Total PnL',
              '${queue.userPnl >= 0 ? '+' : ''}\$${queue.userPnl.toStringAsFixed(2)}',
              queue.userPnl >= 0 ? AppTheme.solanaGreen : AppTheme.error,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color? color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color ?? Colors.white,
          ),
        ),
      ],
    );
  }

  // ── Matches Section (on gradient) ─────────────────────────────────────────

  Widget _buildMatchesSection(QueueState queue) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sports_esports_rounded,
                  size: 18, color: AppTheme.solanaPurple),
              const SizedBox(width: 8),
              Text(
                'Live Matches',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.solanaGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.solanaGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'LIVE',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.solanaGreen,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (queue.liveMatches.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No active matches right now',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
                ),
              ),
            )
          else
            ...List.generate(queue.liveMatches.length, (i) {
              final match = queue.liveMatches[i];
              return Column(
                children: [
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.06)),
                    ),
                  _buildMatchRow(
                    match.player1,
                    match.player2,
                    match.timeframe,
                    match.player1Leading,
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildMatchRow(String p1, String p2, String timeframe, bool p1Up) {
    return Row(
      children: [
        Expanded(
          child: Text(
            p1,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: p1Up ? AppTheme.solanaGreen : AppTheme.error,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.solanaPurple.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'VS  $timeframe',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white54,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: Text(
            p2,
            textAlign: TextAlign.end,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: p1Up ? AppTheme.error : AppTheme.solanaGreen,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Hero Stat
// ═══════════════════════════════════════════════════════════════════════════════

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  const _HeroStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white38,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Connect Wallet Button
// ═══════════════════════════════════════════════════════════════════════════════

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
    final balance = widget.wallet.usdcBalance ?? 0.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: connected ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: connected
                ? _hovered
                    ? AppTheme.solanaGreen.withValues(alpha: 0.15)
                    : AppTheme.solanaGreen.withValues(alpha: 0.08)
                : _hovered
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: connected
                  ? AppTheme.solanaGreen.withValues(alpha: _hovered ? 0.4 : 0.2)
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: connected
                  ? [
                      // Balance display
                      Icon(Icons.check_circle_rounded,
                          size: 16, color: AppTheme.solanaGreen),
                      const SizedBox(width: 8),
                      Text(
                        '\$${balance.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'USDC',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white38,
                        ),
                      ),
                    ]
                  : [
                      Icon(Icons.account_balance_wallet_rounded,
                          size: 18, color: Colors.white54),
                      const SizedBox(width: 8),
                      Text(
                        'Connect Wallet',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
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

// ═══════════════════════════════════════════════════════════════════════════════
// Info Tile
// ═══════════════════════════════════════════════════════════════════════════════

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.white38),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: Colors.white38,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Join Queue Button
// ═══════════════════════════════════════════════════════════════════════════════

class _JoinQueueButton extends StatefulWidget {
  final bool isConnected;
  final String timeframeLabel;
  final int betAmount;
  final VoidCallback onTap;
  const _JoinQueueButton({
    required this.isConnected,
    required this.timeframeLabel,
    required this.betAmount,
    required this.onTap,
  });

  @override
  State<_JoinQueueButton> createState() => _JoinQueueButtonState();
}

// ═══════════════════════════════════════════════════════════════════════════════
// Leave Queue Button (searching state)
// ═══════════════════════════════════════════════════════════════════════════════

class _LeaveQueueButton extends StatefulWidget {
  final int waitSeconds;
  final VoidCallback onTap;
  const _LeaveQueueButton({required this.waitSeconds, required this.onTap});

  @override
  State<_LeaveQueueButton> createState() => _LeaveQueueButtonState();
}

class _LeaveQueueButtonState extends State<_LeaveQueueButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
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
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final glow = 0.15 + _pulseController.value * 0.15;
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.solanaPurple.withValues(alpha: 0.3),
                    AppTheme.solanaPurple.withValues(alpha: 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: AppTheme.solanaPurple.withValues(alpha: 0.5),
                ),
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
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Searching for opponent... $waitStr',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _hovered
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
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

// ═══════════════════════════════════════════════════════════════════════════════
// Highlight Wallet Button — pulsing glow after onboarding finishes
// ═══════════════════════════════════════════════════════════════════════════════

class _HighlightWalletButton extends ConsumerStatefulWidget {
  final GlobalKey globalKey;
  final Widget child;
  const _HighlightWalletButton({required this.globalKey, required this.child});

  @override
  ConsumerState<_HighlightWalletButton> createState() =>
      _HighlightWalletButtonState();
}

class _HighlightWalletButtonState extends ConsumerState<_HighlightWalletButton>
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

    // Listen for highlight changes outside of build
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
      height: 44,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            decoration: highlight
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
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

class _JoinQueueButtonState extends State<_JoinQueueButton> {
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
                    ? const LinearGradient(
                        colors: [
                          AppTheme.solanaPurpleDark,
                          AppTheme.solanaPurple
                        ],
                      )
                    : AppTheme.purpleGradient)
                : LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.white.withValues(alpha: 0.04),
                    ],
                  ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: widget.isConnected
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: _hovered && widget.isConnected
                ? [
                    BoxShadow(
                      color: AppTheme.solanaPurple.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              widget.isConnected
                  ? 'Join ${widget.timeframeLabel} Queue — \$${widget.betAmount} USDC'
                  : 'Connect Wallet to Play',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
      ),
    );
  }
}
