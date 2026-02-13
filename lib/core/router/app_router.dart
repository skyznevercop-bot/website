import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/arena/screens/arena_screen.dart';
import '../../features/clan/screens/clan_screen.dart';
import '../../features/leaderboard/screens/leaderboard_screen.dart';
import '../../features/learn/screens/learn_screen.dart';
import '../../features/play/screens/play_screen.dart';
import '../../features/portfolio/screens/portfolio_screen.dart';
import '../../features/referral/screens/referral_screen.dart';
import '../../shared/widgets/app_shell.dart';
import '../constants/app_constants.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppConstants.playRoute,
    routes: [
      // Arena is full-screen (no AppShell)
      GoRoute(
        path: AppConstants.arenaRoute,
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final duration = extra['duration'] as int? ?? 300;
          final bet = extra['bet'] as double? ?? 100;
          return NoTransitionPage(
            child: ArenaScreen(
              durationSeconds: duration,
              betAmount: bet,
              matchId: extra['matchId'] as String?,
              opponentAddress: extra['opponentAddress'] as String?,
              opponentGamerTag: extra['opponentGamerTag'] as String?,
            ),
          );
        },
      ),
      ShellRoute(
        pageBuilder: (context, state, child) => NoTransitionPage(
          child: AppShell(child: child),
        ),
        routes: [
          GoRoute(
            path: AppConstants.playRoute,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PlayScreen(),
            ),
          ),
          GoRoute(
            path: AppConstants.clanRoute,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ClanScreen(),
            ),
          ),
          GoRoute(
            path: AppConstants.leaderboardRoute,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: LeaderboardScreen(),
            ),
          ),
          GoRoute(
            path: AppConstants.portfolioRoute,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PortfolioScreen(),
            ),
          ),
          GoRoute(
            path: AppConstants.learnRoute,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: LearnScreen(),
            ),
          ),
          GoRoute(
            path: AppConstants.referralRoute,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ReferralScreen(),
            ),
          ),
        ],
      ),
    ],
  );
});
