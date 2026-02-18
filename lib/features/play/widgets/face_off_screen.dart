import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../arena/utils/arena_helpers.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../providers/queue_provider.dart';

// =============================================================================
// Face-Off Screen — Full-screen cinematic match-found experience
// No more deposit stepper. Balance was already frozen at queue-join time.
// Shows dramatic face-off animation then auto-navigates to arena.
// =============================================================================

class FaceOffScreen extends ConsumerStatefulWidget {
  final MatchFoundData match;
  final int durationSeconds;

  const FaceOffScreen({
    super.key,
    required this.match,
    required this.durationSeconds,
  });

  @override
  ConsumerState<FaceOffScreen> createState() => _FaceOffScreenState();
}

class _FaceOffScreenState extends ConsumerState<FaceOffScreen>
    with TickerProviderStateMixin {
  // ── Animations ──
  late AnimationController _slideCtrl;
  late Animation<Offset> _leftSlide;
  late Animation<Offset> _rightSlide;

  late AnimationController _vsCtrl;
  late Animation<double> _vsScale;

  late AnimationController _fadeCtrl;

  late AnimationController _countdownCtrl;

  int _countdown = 3;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();

    // Player cards slide in from sides.
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _leftSlide = Tween<Offset>(
      begin: const Offset(-1.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideCtrl,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
    ));
    _rightSlide = Tween<Offset>(
      begin: const Offset(1.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideCtrl,
      curve: const Interval(0.15, 0.85, curve: Curves.easeOutCubic),
    ));

    // VS text elastic bounce.
    _vsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _vsScale = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _vsCtrl, curve: Curves.elasticOut),
    );

    // Overall fade in.
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Countdown pulse.
    _countdownCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Start animation sequence.
    _fadeCtrl.forward();
    _slideCtrl.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _vsCtrl.forward();
    });

    // Start countdown after animations complete.
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _startCountdown();
    });
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _vsCtrl.dispose();
    _fadeCtrl.dispose();
    _countdownCtrl.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _countdownTimer?.cancel();
        return;
      }
      setState(() => _countdown--);
      _countdownCtrl.forward(from: 0);
      if (_countdown <= 0) {
        _countdownTimer?.cancel();
        _navigateToArena();
      }
    });
  }

  void _navigateToArena() {
    final match = widget.match;
    final params = <String, String>{
      'matchId': match.matchId,
      'd': widget.durationSeconds.toString(),
      'bet': match.bet.toString(),
      'opp': match.opponentAddress,
      'oppTag': match.opponentGamerTag,
    };

    // Use startTime/endTime from the match if available.
    if (match.startTime != null) {
      final endTime = match.startTime! + (widget.durationSeconds * 1000);
      params['et'] = endTime.toString();
    } else if (match.endTime != null) {
      params['et'] = match.endTime.toString();
    } else {
      params['st'] = DateTime.now().millisecondsSinceEpoch.toString();
    }

    if (mounted) {
      ref.read(queueProvider.notifier).resetSearchPhase();
      context.go(
        Uri(path: AppConstants.arenaRoute, queryParameters: params).toString(),
      );
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final myTag =
        ref.watch(walletProvider.select((w) => w.gamerTag)) ?? 'You';

    return FadeTransition(
      opacity: _fadeCtrl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                const Color(0xFF1a1025).withValues(alpha: 0.97),
                const Color(0xFF0a0a0f),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 20 : 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Player cards + VS ──
                      _buildFaceOff(myTag, isMobile),

                      const SizedBox(height: 32),

                      // ── Match details ──
                      _buildMatchDetails(),

                      const SizedBox(height: 20),

                      // ── Balance info ──
                      _buildBalanceInfo(),

                      const SizedBox(height: 32),

                      // ── Countdown ──
                      _buildCountdown(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Face-off header ──

  Widget _buildFaceOff(String myTag, bool isMobile) {
    return Row(
      children: [
        // You.
        Expanded(
          child: SlideTransition(
            position: _leftSlide,
            child: _PlayerCard(
              tag: myTag,
              label: 'YOU',
              color: AppTheme.solanaPurple,
              alignment: CrossAxisAlignment.end,
            ),
          ),
        ),

        // VS.
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
          child: ScaleTransition(
            scale: _vsScale,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.solanaPurple.withValues(alpha: 0.3),
                    const Color(0xFFFF6B35).withValues(alpha: 0.3),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.solanaPurple.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'VS',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Opponent.
        Expanded(
          child: SlideTransition(
            position: _rightSlide,
            child: _PlayerCard(
              tag: widget.match.opponentGamerTag,
              label: 'OPPONENT',
              color: const Color(0xFFFF6B35),
              alignment: CrossAxisAlignment.start,
            ),
          ),
        ),
      ],
    );
  }

  // ── Match details row ──

  Widget _buildMatchDetails() {
    final durationLabel = _formatDuration(widget.durationSeconds);
    final potSize = (widget.match.bet * 2).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _DetailItem(
              icon: Icons.toll_rounded,
              label: 'Bet',
              value: '\$${widget.match.bet.toStringAsFixed(0)}'),
          Container(
              width: 1,
              height: 28,
              color: Colors.white.withValues(alpha: 0.08)),
          _DetailItem(
              icon: Icons.timer_outlined,
              label: 'Duration',
              value: durationLabel),
          Container(
              width: 1,
              height: 28,
              color: Colors.white.withValues(alpha: 0.08)),
          _DetailItem(
              icon: Icons.emoji_events_rounded,
              label: 'Pot',
              value: '\$$potSize'),
        ],
      ),
    );
  }

  // ── Balance info (replaces escrow info) ──

  Widget _buildBalanceInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.solanaGreen.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppTheme.solanaGreen.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded,
              size: 14,
              color: AppTheme.solanaGreen.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Bet locked from your balance. Winner takes the pot minus 10% rake.',
              style: interStyle(
                fontSize: 11,
                color: Colors.white54,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Countdown display ──

  Widget _buildCountdown() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _countdownCtrl,
          builder: (context, child) {
            final scale = 1.0 + (1.0 - _countdownCtrl.value) * 0.3;
            return Transform.scale(
              scale: _countdown > 0 ? scale : 1.0,
              child: child,
            );
          },
          child: Text(
            _countdown > 0 ? '$_countdown' : 'GO!',
            style: GoogleFonts.inter(
              fontSize: _countdown > 0 ? 48 : 56,
              fontWeight: FontWeight.w900,
              color: _countdown > 0
                  ? Colors.white
                  : AppTheme.solanaGreen,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _countdown > 0 ? 'Match starting...' : 'Entering Arena...',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white38,
          ),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    if (seconds >= 3600) return '${seconds ~/ 3600}h';
    return '${seconds ~/ 60}m';
  }
}

// =============================================================================
// Player Card
// =============================================================================

class _PlayerCard extends StatelessWidget {
  final String tag;
  final String label;
  final Color color;
  final CrossAxisAlignment alignment;

  const _PlayerCard({
    required this.tag,
    required this.label,
    required this.color,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        // Avatar circle.
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.15),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.2),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              tag.isNotEmpty ? tag.substring(0, 2).toUpperCase() : '??',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Label.
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white38,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),

        // Tag.
        Text(
          tag,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// =============================================================================
// Detail Item
// =============================================================================

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailItem({
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
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, color: Colors.white38),
        ),
      ],
    );
  }
}
