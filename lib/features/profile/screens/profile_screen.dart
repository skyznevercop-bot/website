import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../achievements/models/achievement_models.dart';
import '../../achievements/providers/achievement_provider.dart';
import '../../achievements/widgets/achievement_grid.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/deep_stats_section.dart';
import '../widgets/match_history_section.dart';
import '../widgets/profile_header.dart';
import '../widgets/stats_overview.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String walletAddress;

  const ProfileScreen({super.key, required this.walletAddress});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(profileProvider.notifier).fetchProfile(widget.walletAddress);
      ref
          .read(achievementProvider.notifier)
          .fetchAchievements(widget.walletAddress);
    });
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.walletAddress != widget.walletAddress) {
      ref.read(profileProvider.notifier).fetchProfile(widget.walletAddress);
      ref
          .read(achievementProvider.notifier)
          .fetchAchievements(widget.walletAddress);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileProvider);
    final achievementState = ref.watch(achievementProvider);
    final wallet = ref.watch(walletProvider);
    final isOwnProfile = wallet.address == widget.walletAddress;

    if (state.isLoading && state.profile == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.solanaPurple),
      );
    }

    if (state.error != null && state.profile == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppTheme.textTertiary, size: 48),
            const SizedBox(height: 12),
            Text(
              'Player not found',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final profile = state.profile;
    if (profile == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 64),
      child: Center(
        child: Container(
          width: Responsive.value<double>(context,
              mobile: double.infinity, tablet: 720, desktop: 800),
          padding: Responsive.horizontalPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),

              // Profile Header
              ProfileHeader(
                profile: profile,
                isOwnProfile: isOwnProfile,
              ),
              const SizedBox(height: 32),

              // Stats Overview
              _sectionHeader(
                Icons.bar_chart_rounded,
                AppTheme.solanaPurple,
                'Stats Overview',
              ),
              const SizedBox(height: 16),
              StatsOverview(profile: profile),
              const SizedBox(height: 32),

              // Deep Stats
              _sectionHeader(
                Icons.insights_rounded,
                AppTheme.solanaGreen,
                'Trading Analytics',
              ),
              const SizedBox(height: 16),
              DeepStatsSection(stats: profile.deepStats),
              const SizedBox(height: 32),

              // Achievements
              _sectionHeader(
                Icons.military_tech_rounded,
                AppTheme.warning,
                'Achievements',
              ),
              const SizedBox(height: 16),
              if (achievementState.isLoading &&
                  achievementState.achievements.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.solanaPurple),
                  ),
                )
              else
                AchievementGrid(
                  achievements: achievementState.achievements.isNotEmpty
                      ? achievementState.achievements
                      : _achievementsFromMap(profile.achievements),
                  unlockedCount: achievementState.unlockedCount > 0
                      ? achievementState.unlockedCount
                      : profile.achievements.values
                          .where((v) => v)
                          .length,
                  totalCount: achievementState.totalCount > 0
                      ? achievementState.totalCount
                      : 18,
                ),
              const SizedBox(height: 32),

              // Match History
              _sectionHeader(
                Icons.history_rounded,
                AppTheme.info,
                'Recent Matches',
              ),
              const SizedBox(height: 16),
              MatchHistorySection(matches: profile.recentMatches),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, Color color, String title) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  /// Fallback: convert profile achievements map to Achievement list
  List<Achievement> _achievementsFromMap(Map<String, bool> map) {
    // Return empty if we don't have the full catalog
    return [];
  }
}
