import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../models/achievement_models.dart';
import '../providers/achievement_provider.dart';

class AchievementToastOverlay extends ConsumerStatefulWidget {
  const AchievementToastOverlay({super.key});

  @override
  ConsumerState<AchievementToastOverlay> createState() =>
      _AchievementToastOverlayState();
}

class _AchievementToastOverlayState
    extends ConsumerState<AchievementToastOverlay>
    with SingleTickerProviderStateMixin {
  StreamSubscription<Achievement>? _subscription;
  Achievement? _currentAchievement;
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    // Subscribe to toast stream after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(achievementProvider.notifier);
      _subscription = notifier.toastStream.listen(_showToast);
    });
  }

  void _showToast(Achievement achievement) {
    _dismissTimer?.cancel();
    setState(() => _currentAchievement = achievement);
    _animController.forward(from: 0);
    _dismissTimer = Timer(const Duration(seconds: 4), _hideToast);
  }

  void _hideToast() {
    _animController.reverse().then((_) {
      if (mounted) setState(() => _currentAchievement = null);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _dismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep provider alive
    ref.watch(achievementProvider);

    if (_currentAchievement == null) return const SizedBox.shrink();

    final achievement = _currentAchievement!;

    return Positioned(
      top: 80,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: _hideToast,
            child: Container(
              width: 300,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2D1B69), Color(0xFF4A2198)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(
                  color: AppTheme.solanaPurple.withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.solanaPurple.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      achievement.iconData,
                      color: AppTheme.solanaGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Achievement Unlocked!',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.solanaGreen,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          achievement.name,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          achievement.description,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
}
