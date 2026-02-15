import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../features/arena/providers/trading_provider.dart';
import '../../features/onboarding/providers/onboarding_provider.dart';
import '../../features/onboarding/widgets/onboarding_overlay.dart';
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

  @override
  Widget build(BuildContext context) {
    // When wallet connects, check for an ongoing match.
    ref.listen(walletProvider, (prev, next) {
      if (next.isConnected && !(prev?.isConnected ?? false) && next.address != null) {
        ref.read(tradingProvider.notifier).checkActiveMatch(next.address!);
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
