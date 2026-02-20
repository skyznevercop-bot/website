import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/about/screens/about_screen.dart';
import '../../features/arena/screens/arena_screen.dart';
import '../../features/clan/screens/clan_screen.dart';
import '../../features/feedback/screens/feedback_screen.dart';
import '../../features/friends/screens/friends_screen.dart';
import '../../features/help/screens/help_screen.dart';
import '../../features/leaderboard/screens/leaderboard_screen.dart';
import '../../features/learn/screens/learn_screen.dart';
import '../../features/play/screens/play_screen.dart';
import '../../features/portfolio/screens/portfolio_screen.dart';
import '../../features/privacy/screens/privacy_screen.dart';
import '../../features/referral/screens/referral_screen.dart';
import '../../features/rules/screens/rules_screen.dart';
import '../../features/terms/screens/terms_screen.dart';
import '../../shared/widgets/app_shell.dart';
import '../constants/app_constants.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppConstants.playRoute,
    routes: [
      // Arena is full-screen (no AppShell). Match data in query params survives refresh.
      GoRoute(
        path: AppConstants.arenaRoute,
        pageBuilder: (context, state) {
          final qp = state.uri.queryParameters;
          final duration = int.tryParse(qp['d'] ?? '') ?? 300;
          final bet = double.tryParse(qp['bet'] ?? '') ?? 100;
          return NoTransitionPage(
            child: ArenaScreen(
              durationSeconds: duration,
              betAmount: bet,
              matchId: qp['matchId'],
              opponentAddress: qp['opp'],
              opponentGamerTag: qp['oppTag'],
              endTime: int.tryParse(qp['et'] ?? ''),
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
            path: AppConstants.friendsRoute,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: FriendsScreen(),
            ),
          ),
          GoRoute(
            path: AppConstants.referralRoute,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ReferralScreen(),
            ),
          ),
          GoRoute(
            path: AppConstants.helpRoute,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HelpScreen(),
            ),
          ),
          GoRoute(
            path: AppConstants.rulesRoute,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: RulesScreen(),
            ),
          ),
          GoRoute(
            path: AppConstants.feedbackRoute,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: FeedbackScreen(),
            ),
          ),
          GoRoute(
            path: AppConstants.aboutRoute,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AboutScreen(),
            ),
          ),
          GoRoute(
            path: AppConstants.privacyRoute,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PrivacyScreen(),
            ),
          ),
          GoRoute(
            path: AppConstants.termsRoute,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TermsScreen(),
            ),
          ),
        ],
      ),
    ],
  );
});
