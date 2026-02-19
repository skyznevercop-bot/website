import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/settings_service.dart';
import '../../../core/theme/app_theme.dart';
import '../models/trading_models.dart';
import '../providers/trading_provider.dart';
import '../utils/arena_helpers.dart';

// =============================================================================
// Phase Banner — Animated slide-down announcements on phase transitions
// =============================================================================

class PhaseBanner extends ConsumerStatefulWidget {
  const PhaseBanner({super.key});

  @override
  ConsumerState<PhaseBanner> createState() => _PhaseBannerState();
}

class _PhaseBannerState extends ConsumerState<PhaseBanner>
    with TickerProviderStateMixin {
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  MatchPhase? _currentBannerPhase;
  MatchPhase? _lastSeenPhase;

  @override
  void initState() {
    super.initState();

    // Slide in/out from top.
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    ));
    _fadeAnim = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut),
    );

    // Pulsing glow for Final Sprint.
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnim = Tween(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Shake for Last Stand.
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 60),
    );
    _shakeAnim = Tween(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _pulseCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _showBanner(MatchPhase phase) {
    // Only show banners for significant phase transitions.
    if (phase == MatchPhase.intro ||
        phase == MatchPhase.ended ||
        phase == MatchPhase.midGame) {
      return;
    }

    _currentBannerPhase = phase;
    _slideCtrl.forward(from: 0);

    // Start secondary animations.
    final shakeEnabled = ref.read(settingsProvider).screenShakeEnabled;
    if (phase == MatchPhase.finalSprint) {
      _pulseCtrl.repeat(reverse: true);
    } else if (phase == MatchPhase.lastStand) {
      if (shakeEnabled) _shakeCtrl.repeat(reverse: true);
      _pulseCtrl.repeat(reverse: true);
    }

    // Auto-dismiss.
    final holdDuration = phase == MatchPhase.openingBell
        ? const Duration(seconds: 2)
        : const Duration(seconds: 3);

    Future.delayed(holdDuration, () {
      if (mounted) {
        _slideCtrl.reverse();
        _pulseCtrl.stop();
        _shakeCtrl.stop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final phase = ref.watch(
      tradingProvider.select((s) => s.matchPhase),
    );

    // Detect phase transitions.
    if (phase != _lastSeenPhase) {
      final prevPhase = _lastSeenPhase;
      _lastSeenPhase = phase;
      if (prevPhase != null) {
        // Schedule the banner show after build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showBanner(phase);
        });
      }
    }

    if (_currentBannerPhase == null) return const SizedBox.shrink();

    final bannerPhase = _currentBannerPhase!;
    final color = phaseColor(bannerPhase);
    final label = phaseLabel(bannerPhase);
    final subtitle = _phaseSubtitle(bannerPhase);

    return Positioned(
      top: 60,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_pulseCtrl, _shakeCtrl]),
              builder: (context, child) {
                final dx = _shakeCtrl.isAnimating ? _shakeAnim.value : 0.0;
                final glowAlpha = _pulseCtrl.isAnimating
                    ? _pulseAnim.value
                    : 0.8;

                return Transform.translate(
                  offset: Offset(dx, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: color.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color
                              .withValues(alpha: 0.3 * glowAlpha),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_phaseIcon(bannerPhase),
                                size: 18, color: color),
                            const SizedBox(width: 10),
                            Text(
                              label,
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: color,
                                letterSpacing: 3,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(_phaseIcon(bannerPhase),
                                size: 18, color: color),
                          ],
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: interStyle(
                              fontSize: 11,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  IconData _phaseIcon(MatchPhase phase) {
    switch (phase) {
      case MatchPhase.openingBell:
        return Icons.notifications_active_rounded;
      case MatchPhase.finalSprint:
        return Icons.bolt_rounded;
      case MatchPhase.lastStand:
        return Icons.local_fire_department_rounded;
      default:
        return Icons.timer_rounded;
    }
  }

  String? _phaseSubtitle(MatchPhase phase) {
    switch (phase) {
      case MatchPhase.openingBell:
        return 'Make your opening moves';
      case MatchPhase.finalSprint:
        return 'Time is running out — trade aggressively';
      case MatchPhase.lastStand:
        return 'Final moments — every trade counts';
      default:
        return null;
    }
  }
}
