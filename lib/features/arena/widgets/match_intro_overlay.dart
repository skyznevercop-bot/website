import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../utils/arena_helpers.dart';

// =============================================================================
// Match Intro Overlay — Cinematic 3-2-1-FIGHT countdown on match start
// =============================================================================

class MatchIntroOverlay extends StatefulWidget {
  final String? opponentTag;
  final int durationSeconds;
  final double betAmount;
  final VoidCallback onComplete;

  const MatchIntroOverlay({
    super.key,
    this.opponentTag,
    required this.durationSeconds,
    required this.betAmount,
    required this.onComplete,
  });

  @override
  State<MatchIntroOverlay> createState() => _MatchIntroOverlayState();
}

class _MatchIntroOverlayState extends State<MatchIntroOverlay>
    with TickerProviderStateMixin {
  // Phase: 0=ready, 1=3, 2=2, 3=1, 4=FIGHT, 5=fade out
  int _phase = 0;

  late AnimationController _numberCtrl;
  late Animation<double> _numberScale;
  late Animation<double> _numberOpacity;

  late AnimationController _fightCtrl;
  late Animation<double> _fightScale;
  late Animation<double> _fightOpacity;

  late AnimationController _backdropCtrl;
  late Animation<double> _backdropOpacity;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseScale;

  Timer? _sequenceTimer;

  @override
  void initState() {
    super.initState();

    // Number scale-in animation (used for 3, 2, 1).
    _numberCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _numberScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 2.5, end: 0.9)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.9, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_numberCtrl);
    _numberOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_numberCtrl);

    // FIGHT text explosion.
    _fightCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fightScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.2)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.5)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_fightCtrl);
    _fightOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_fightCtrl);

    // Backdrop fade.
    _backdropCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _backdropOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _backdropCtrl, curve: Curves.easeOut),
    );

    // Background pulse ring.
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseScale = Tween(begin: 0.3, end: 1.5).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );

    _startSequence();
  }

  void _startSequence() {
    // Fade in backdrop.
    _backdropCtrl.forward();

    // Phase 0 → "GET READY" shows briefly (500ms), then countdown.
    _sequenceTimer = Timer(const Duration(milliseconds: 600), () {
      _showNumber(1); // phase 1 = "3"
    });
  }

  void _showNumber(int phase) {
    if (!mounted) return;
    setState(() => _phase = phase);
    _numberCtrl.forward(from: 0);
    _pulseCtrl.forward(from: 0);

    if (phase < 4) {
      // 3 → 2 → 1: 800ms per number.
      _sequenceTimer = Timer(const Duration(milliseconds: 800), () {
        _showNumber(phase + 1);
      });
    } else {
      // FIGHT!
      _fightCtrl.forward(from: 0);
      _sequenceTimer = Timer(const Duration(milliseconds: 900), () {
        _fadeOut();
      });
    }
  }

  void _fadeOut() {
    if (!mounted) return;
    setState(() => _phase = 5);
    _backdropCtrl.reverse().then((_) {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _sequenceTimer?.cancel();
    _numberCtrl.dispose();
    _fightCtrl.dispose();
    _backdropCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  /// Color for each countdown number.
  Color _countdownColor() {
    switch (_phase) {
      case 1:
        return Colors.white; // "3"
      case 2:
        return AppTheme.warning; // "2"
      case 3:
        return AppTheme.error; // "1"
      case 4:
        return AppTheme.solanaGreen; // "FIGHT!"
      default:
        return Colors.white;
    }
  }

  /// Display text for current countdown phase.
  String _countdownText() {
    switch (_phase) {
      case 1:
        return '3';
      case 2:
        return '2';
      case 3:
        return '1';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _backdropCtrl,
      builder: (context, _) {
        if (_backdropOpacity.value <= 0 && _phase == 5) {
          return const SizedBox.shrink();
        }

        return Opacity(
          opacity: _backdropOpacity.value,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    const Color(0xFF1a1025).withValues(alpha: 0.95),
                    const Color(0xFF0a0a0f).withValues(alpha: 0.98),
                  ],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // ── Pulse ring ──
                  if (_phase >= 1 && _phase <= 4)
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (context, _) {
                        return Transform.scale(
                          scale: _pulseScale.value,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _countdownColor().withValues(
                                    alpha:
                                        0.3 * (1.0 - _pulseCtrl.value)),
                                width: 3,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  // ── Countdown numbers (3, 2, 1) ──
                  if (_phase >= 1 && _phase <= 3)
                    AnimatedBuilder(
                      animation: _numberCtrl,
                      builder: (context, _) {
                        return Opacity(
                          opacity: _numberOpacity.value.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: _numberScale.value,
                            child: Text(
                              _countdownText(),
                              style: GoogleFonts.inter(
                                fontSize: 120,
                                fontWeight: FontWeight.w900,
                                color: _countdownColor(),
                                letterSpacing: -4,
                                shadows: [
                                  Shadow(
                                    color: _countdownColor()
                                        .withValues(alpha: 0.5),
                                    blurRadius: 40,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  // ── FIGHT! text ──
                  if (_phase == 4)
                    AnimatedBuilder(
                      animation: _fightCtrl,
                      builder: (context, _) {
                        return Opacity(
                          opacity: _fightOpacity.value.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: _fightScale.value,
                            child: ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [
                                  AppTheme.solanaGreen,
                                  AppTheme.solanaPurple,
                                ],
                              ).createShader(bounds),
                              child: Text(
                                'FIGHT!',
                                style: GoogleFonts.inter(
                                  fontSize: 80,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 6,
                                  shadows: [
                                    Shadow(
                                      color: AppTheme.solanaGreen
                                          .withValues(alpha: 0.6),
                                      blurRadius: 60,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  // ── "GET READY" label (phase 0) ──
                  if (_phase == 0)
                    Text(
                      'GET READY',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                        letterSpacing: 8,
                      ),
                    ),

                  // ── Opponent tag + match info ──
                  Positioned(
                    bottom: 120,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.opponentTag != null) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('vs ',
                                  style: interStyle(
                                    fontSize: 16,
                                    color: AppTheme.textTertiary,
                                  )),
                              Text(widget.opponentTag!,
                                  style: interStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFFF6B35),
                                  )),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _InfoChip(
                              icon: Icons.timer_outlined,
                              label: _formatDuration(
                                  widget.durationSeconds),
                            ),
                            const SizedBox(width: 12),
                            _InfoChip(
                              icon: Icons.toll_rounded,
                              label:
                                  '\$${widget.betAmount.toStringAsFixed(0)} USDC',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Spark particles ──
                  if (_phase >= 1 && _phase <= 4)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _SparkPainter(
                            progress: _phase == 4
                                ? _fightCtrl.value
                                : _numberCtrl.value,
                            color: _countdownColor(),
                            seed: _phase,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(int seconds) {
    if (seconds >= 3600) {
      final h = seconds ~/ 3600;
      return '${h}h';
    }
    return '${seconds ~/ 60}m';
  }
}

// =============================================================================
// Info Chip — Duration / Bet display
// =============================================================================

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.border.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textTertiary),
          const SizedBox(width: 6),
          Text(label,
              style: interStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              )),
        ],
      ),
    );
  }
}

// =============================================================================
// Spark Particle Painter — Decorative sparks radiating from center
// =============================================================================

class _SparkPainter extends CustomPainter {
  final double progress;
  final Color color;
  final int seed;

  _SparkPainter({
    required this.progress,
    required this.color,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rng = Random(seed * 42);
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 12; i++) {
      final angle = rng.nextDouble() * 2 * pi;
      final maxDist = 80 + rng.nextDouble() * 120;
      final dist = maxDist * progress;
      final sparkSize = (3.0 - progress * 2.5).clamp(0.5, 3.0);
      final opacity = (1.0 - progress).clamp(0.0, 0.8);

      final pos = Offset(
        center.dx + cos(angle) * dist,
        center.dy + sin(angle) * dist,
      );

      paint.color = color.withValues(alpha: opacity);
      canvas.drawCircle(pos, sparkSize, paint);
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      progress != old.progress || seed != old.seed;
}
