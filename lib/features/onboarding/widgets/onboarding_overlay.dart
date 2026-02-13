import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../models/onboarding_state.dart';
import '../providers/onboarding_provider.dart';
import 'onboarding_keys.dart';
import 'spotlight_painter.dart';

/// Full-screen onboarding overlay with animated spotlight cutout + tooltip.
class OnboardingOverlay extends ConsumerStatefulWidget {
  const OnboardingOverlay({super.key});

  @override
  ConsumerState<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends ConsumerState<OnboardingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  Rect? _currentRect;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    // Drive fade animation from provider state changes (not inside build)
    ref.listenManual(
      onboardingProvider.select((s) => s.isActive),
      (previous, isActive) {
        if (isActive) {
          _fadeController.forward();
        } else {
          _fadeController.reverse();
        }
      },
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  /// Finds the bounding rect of the widget attached to the given [GlobalKey],
  /// in global (screen) coordinates, with padding.
  Rect? _getTargetRect(GlobalKey key) {
    final renderObj = key.currentContext?.findRenderObject();
    if (renderObj is! RenderBox || !renderObj.hasSize) return null;

    final offset = renderObj.localToGlobal(Offset.zero);
    final size = renderObj.size;
    const padding = 8.0;

    return Rect.fromLTWH(
      offset.dx - padding,
      offset.dy - padding,
      size.width + padding * 2,
      size.height + padding * 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingProvider);
    final keys = ref.watch(onboardingKeysProvider);

    // Desktop only for now
    if (Responsive.isMobile(context)) return const SizedBox.shrink();
    if (!onboardingState.isActive || keys == null) {
      return const SizedBox.shrink();
    }

    final step = onboardingState.currentStep;
    final targetKey = keys.keyForStepId(step.id);
    final targetRect = _getTargetRect(targetKey);

    if (targetRect == null) {
      // Layout not ready yet — schedule a rebuild next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return const SizedBox.shrink();
    }

    _currentRect ??= targetRect;

    final screenSize = MediaQuery.sizeOf(context);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: TweenAnimationBuilder<Rect?>(
        tween: RectTween(begin: _currentRect, end: targetRect),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        onEnd: () => _currentRect = targetRect,
        builder: (context, animatedRect, _) {
          final rect = animatedRect ?? targetRect;

          return Stack(
            children: [
              // ── Dark overlay with spotlight cutout ──────────────
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {}, // absorb taps
                  child: CustomPaint(
                    painter: SpotlightPainter(
                      spotlightRect: rect,
                      overlayColor: Colors.black.withValues(alpha: 0.70),
                      borderRadius: 12.0,
                    ),
                  ),
                ),
              ),

              // ── Purple glow border around cutout ───────────────
              Positioned(
                left: rect.left - 2,
                top: rect.top - 2,
                width: rect.width + 4,
                height: rect.height + 4,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.solanaPurple.withValues(alpha: 0.6),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.solanaPurple.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Tooltip card ───────────────────────────────────
              _buildTooltip(
                rect: rect,
                step: step,
                state: onboardingState,
                screenSize: screenSize,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTooltip({
    required Rect rect,
    required OnboardingStep step,
    required OnboardingState state,
    required Size screenSize,
  }) {
    const tooltipWidth = 320.0;
    const tooltipMargin = 20.0;

    // Prefer placing tooltip to the right of the spotlight
    double left;
    double top;

    final rightSpace = screenSize.width - rect.right;
    final leftSpace = rect.left;

    if (rightSpace >= tooltipWidth + tooltipMargin * 2) {
      // Place to the right
      left = rect.right + tooltipMargin;
      top = rect.top;
    } else if (leftSpace >= tooltipWidth + tooltipMargin * 2) {
      // Place to the left
      left = rect.left - tooltipWidth - tooltipMargin;
      top = rect.top;
    } else {
      // Place below
      left = rect.center.dx - tooltipWidth / 2;
      top = rect.bottom + tooltipMargin;
    }

    // Clamp to screen bounds
    left = left.clamp(16.0, screenSize.width - tooltipWidth - 16);
    top = top.clamp(16.0, screenSize.height - 280);

    return Positioned(
      left: left,
      top: top,
      width: tooltipWidth,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: AppTheme.solanaPurple.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AppTheme.solanaPurple.withValues(alpha: 0.1),
                blurRadius: 40,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Step indicator
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.solanaPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Step ${state.currentStepIndex + 1} of ${state.totalSteps}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.solanaPurpleLight,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title
              Text(
                step.title,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                step.description,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.white60,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),

              // Progress dots
              Row(
                children: List.generate(state.totalSteps, (i) {
                  final isActive = i == state.currentStepIndex;
                  return Container(
                    width: isActive ? 20 : 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.solanaPurple
                          : AppTheme.solanaPurple.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),

              // Buttons
              Row(
                children: [
                  // Skip
                  MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () =>
                            ref.read(onboardingProvider.notifier).skip(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 4),
                          child: Text(
                            'Skip',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white38,
                            ),
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  // Next / Connect Your Wallet
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        if (state.isLastStep) {
                          ref
                              .read(onboardingProvider.notifier)
                              .finishWithHighlight();
                        } else {
                          ref.read(onboardingProvider.notifier).nextStep();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: AppTheme.purpleGradient,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.solanaPurple
                                  .withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          state.isLastStep ? 'Finish & Play' : 'Next',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
