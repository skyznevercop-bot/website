import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../features/arena/providers/trading_provider.dart';
import '../../features/onboarding/providers/onboarding_provider.dart';
import '../../features/achievements/widgets/achievement_toast.dart';
import '../../features/onboarding/widgets/onboarding_overlay.dart';
import '../../features/play/providers/queue_provider.dart';
import '../../features/play/widgets/face_off_screen.dart';
import '../../features/referral/providers/referral_provider.dart';
import '../../features/wallet/providers/wallet_provider.dart';
import 'top_bar.dart';

/// Root shell widget containing the persistent top bar and bottom nav (mobile).
/// The [child] is the currently routed screen from GoRouter's ShellRoute.
class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Trigger onboarding on first visit.
      ref.read(onboardingProvider.notifier).maybeStartOnboarding();
      // Ensure the queue provider's WS listener is always active so
      // match_found events (from challenges or matchmaking) are handled
      // regardless of which screen the user is on.
      ref.read(queueProvider.notifier).init();
      // Check for active match if wallet is already connected.
      _checkForActiveMatch();
    });
  }

  void _checkForActiveMatch() {
    final wallet = ref.read(walletProvider);
    if (wallet.isConnected && wallet.address != null) {
      ref.read(tradingProvider.notifier).checkActiveMatch(wallet.address!);
    }
  }

  void _showFaceOff(MatchFoundData match) {
    int durationSec = 300; // Default 5 min.
    final durMatch = RegExp(r'^(\d+)(m|h)$').firstMatch(match.duration);
    if (durMatch != null) {
      final value = int.parse(durMatch.group(1)!);
      durationSec = durMatch.group(2) == 'h' ? value * 3600 : value * 60;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (ctx) => FaceOffScreen(
        match: match,
        durationSeconds: durationSec,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // When wallet connects, check for an ongoing match + apply pending referral.
    ref.listen(walletProvider, (prev, next) {
      if (next.isConnected && !(prev?.isConnected ?? false) && next.address != null) {
        ref.read(tradingProvider.notifier).checkActiveMatch(next.address!);

        // Auto-apply referral code from URL (?ref=CODE) if present.
        final pendingCode = ref.read(pendingReferralCodeProvider);
        if (pendingCode != null && pendingCode.isNotEmpty) {
          ref.read(referralProvider.notifier).applyReferralCode(pendingCode);
        }
      }
    });

    // Global listener: navigate to arena when match_found arrives (from queue or challenge).
    ref.listen<QueueState>(queueProvider, (prev, next) {
      if (next.matchFound != null && prev?.matchFound == null) {
        final match = next.matchFound!;
        ref.read(queueProvider.notifier).clearMatchFound();

        // If already in a match, show notification instead of navigating.
        final trading = ref.read(tradingProvider);
        if (trading.matchActive) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('A new match is waiting for you!'),
                action: SnackBarAction(
                  label: 'GO',
                  onPressed: () {
                    if (trading.arenaRoute != null) {
                      context.go(trading.arenaRoute!);
                    }
                  },
                ),
              ),
            );
          }
          return;
        }

        _showFaceOff(match);
      }
    });

    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              const TopBar(),
              Expanded(child: widget.child),
            ],
          ),
          const OnboardingOverlay(),
          const AchievementToastOverlay(),
        ],
      ),
      // Bottom nav for mobile only
      bottomNavigationBar: isMobile ? _MobileBottomNav() : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Mobile Bottom Navigation
// ═══════════════════════════════════════════════════════════════════════════════

class _MobileBottomNav extends StatelessWidget {
  static const _items = [
    (icon: Icons.sports_esports_rounded, label: 'Play', path: AppConstants.playRoute),
    (icon: Icons.groups_rounded, label: 'Clan', path: AppConstants.clanRoute),
    (icon: Icons.leaderboard_rounded, label: 'Board', path: AppConstants.leaderboardRoute),
    (icon: Icons.pie_chart_rounded, label: 'Portfolio', path: AppConstants.portfolioRoute),
    (icon: Icons.more_horiz_rounded, label: 'More', path: AppConstants.learnRoute),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _items.indexWhere((item) => location == item.path);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final active = index == currentIndex;

              return Expanded(
                child: InkWell(
                  onTap: () => context.go(item.path),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        size: 24,
                        color: active
                            ? AppTheme.solanaPurple
                            : AppTheme.textTertiary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.w400,
                          color: active
                              ? AppTheme.solanaPurple
                              : AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
