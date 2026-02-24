import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../providers/trading_provider.dart';
import '../utils/arena_helpers.dart';
import '../../wallet/providers/wallet_provider.dart';
import 'share_card.dart';

// =============================================================================
// Match Result Overlay — Cinematic victory ceremony with match highlights
// =============================================================================

class MatchResultOverlay extends ConsumerStatefulWidget {
  final TradingState state;
  final double betAmount;

  const MatchResultOverlay({
    super.key,
    required this.state,
    this.betAmount = 0,
  });

  @override
  ConsumerState<MatchResultOverlay> createState() =>
      _MatchResultOverlayState();
}

enum _RevealPhase { pending, countdown, reveal, stats }

class _MatchResultOverlayState extends ConsumerState<MatchResultOverlay>
    with TickerProviderStateMixin {
  // ── Animation state ──
  _RevealPhase _phase = _RevealPhase.pending;
  int _countdownValue = 3;
  late final AnimationController _fadeCtrl;
  late final AnimationController _resultCtrl;
  late final AnimationController _statsCtrl;
  late final AnimationController _roiAnimCtrl;
  late final AnimationController _particleCtrl;
  late final AnimationController _shakeCtrl;
  late final Animation<double> _resultScale;
  late final Animation<double> _resultOpacity;
  late final Animation<double> _statsSlide;

  // ── ROI animation ──
  double _animatedMyRoi = 0;
  double _animatedOppRoi = 0;

  // ── Particles ──
  late final List<_Particle> _particles;

  static const _gold = Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    _resultCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _resultScale = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _resultCtrl, curve: Curves.elasticOut));
    _resultOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _resultCtrl,
            curve: const Interval(0.0, 0.4, curve: Curves.easeOut)));

    _statsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _statsSlide = Tween<double>(begin: 60.0, end: 0.0).animate(
        CurvedAnimation(parent: _statsCtrl, curve: Curves.easeOutCubic));

    _roiAnimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _roiAnimCtrl.addListener(_updateRoiAnimation);

    _particleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000));

    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 80));

    // Generate particles for victory effect.
    final rng = math.Random();
    _particles = List.generate(40, (i) {
      return _Particle(
        x: rng.nextDouble(),
        y: rng.nextDouble() * -0.3,
        vx: (rng.nextDouble() - 0.5) * 0.3,
        vy: 0.3 + rng.nextDouble() * 0.5,
        size: 3 + rng.nextDouble() * 5,
        color: [_gold, AppTheme.solanaPurple, AppTheme.success, Colors.white][
            rng.nextInt(4)],
        rotation: rng.nextDouble() * math.pi * 2,
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fadeCtrl.forward();
        if (_hasResult) {
          _startCountdown();
        } else {
          setState(() => _phase = _RevealPhase.pending);
          // Polling is handled by TradingNotifier — the overlay simply
          // reacts to state changes via didUpdateWidget.
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant MatchResultOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_phase == _RevealPhase.pending && _hasResult) {
      _startCountdown();
    }

    // If server-authoritative ROI arrived after the animation completed,
    // snap the displayed values to the correct server values.
    if (_roiAnimCtrl.isCompleted) {
      final newMyRoi = _myRoi;
      final newOppRoi = _oppRoi;
      if ((_animatedMyRoi - newMyRoi).abs() > 0.01 ||
          (_animatedOppRoi - newOppRoi).abs() > 0.01) {
        setState(() {
          _animatedMyRoi = newMyRoi;
          _animatedOppRoi = newOppRoi;
        });
      }
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _resultCtrl.dispose();
    _statsCtrl.dispose();
    _roiAnimCtrl.removeListener(_updateRoiAnimation);
    _roiAnimCtrl.dispose();
    _particleCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──

  bool get _hasResult =>
      widget.state.isPracticeMode ||
      widget.state.matchWinner != null ||
      widget.state.matchIsTie;

  bool get _isWinner {
    if (widget.state.matchIsTie) return false;
    // Primary: compare winner address to our wallet.
    final wallet = ref.read(walletProvider);
    if (widget.state.matchWinner != null && wallet.address != null) {
      return widget.state.matchWinner == wallet.address;
    }
    // Fallback: use server-authoritative ROI comparison.
    final myRoi = widget.state.serverMyRoi;
    final oppRoi = widget.state.serverOppRoi;
    if (myRoi != null && oppRoi != null) {
      return myRoi > oppRoi;
    }
    return false;
  }

  bool get _isLoser {
    if (widget.state.matchIsTie) return false;
    // Primary: compare winner address to our wallet.
    final wallet = ref.read(walletProvider);
    if (widget.state.matchWinner != null && wallet.address != null) {
      return widget.state.matchWinner != wallet.address;
    }
    // Fallback: use server-authoritative ROI comparison.
    final myRoi = widget.state.serverMyRoi;
    final oppRoi = widget.state.serverOppRoi;
    if (myRoi != null && oppRoi != null) {
      return myRoi < oppRoi;
    }
    return false;
  }

  double get _myRoi {
    // Prefer server-authoritative ROI when available.
    if (widget.state.serverMyRoi != null) return widget.state.serverMyRoi!;
    return widget.state.initialBalance > 0
        ? (widget.state.equity - widget.state.initialBalance) /
            widget.state.initialBalance *
            100
        : 0;
  }

  double get _oppRoi {
    if (widget.state.serverOppRoi != null) return widget.state.serverOppRoi!;
    return widget.state.opponentRoi;
  }

  Color get _resultColor {
    if (widget.state.isPracticeMode) return AppTheme.warning;
    if (widget.state.matchIsTie) return AppTheme.textSecondary;
    return _isWinner ? _gold : AppTheme.error;
  }

  // ── Countdown & reveal ──

  void _startCountdown() {
    setState(() {
      _phase = _RevealPhase.countdown;
      _countdownValue = 3;
    });
    Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownValue <= 1) {
        timer.cancel();
        _showResult();
      } else {
        // Screen shake on each tick (if enabled).
        if (ref.read(settingsProvider).screenShakeEnabled) {
          _shakeCtrl.forward(from: 0).then((_) {
            if (mounted) _shakeCtrl.reverse();
          });
        }
        setState(() => _countdownValue--);
      }
    });
  }

  void _showResult() {
    setState(() => _phase = _RevealPhase.reveal);
    _resultCtrl.forward();

    // Play result sound.
    final audio = AudioService.instance;
    if (widget.state.isPracticeMode) {
      audio.playMatchEnd();
    } else if (widget.state.matchIsTie) {
      audio.playMatchEnd();
    } else if (_isWinner) {
      audio.playVictory();
    } else {
      audio.playDefeat();
    }

    // Start particles for victory.
    if (_isWinner) {
      _particleCtrl.repeat();
    }

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _roiAnimCtrl.forward();
    });

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() => _phase = _RevealPhase.stats);
        _statsCtrl.forward();
      }
    });
  }

  void _updateRoiAnimation() {
    if (!mounted) return;
    final t = Curves.easeOutCubic.transform(_roiAnimCtrl.value);
    setState(() {
      _animatedMyRoi = _myRoi * t;
      _animatedOppRoi = _oppRoi * t;
    });
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeCtrl,
      child: PointerInterceptor(
        child: AnimatedBuilder(
          animation: _shakeCtrl,
          builder: (context, child) {
            final dx = _shakeCtrl.isAnimating
                ? math.sin(_shakeCtrl.value * math.pi * 4) * 4
                : 0.0;
            return Transform.translate(
              offset: Offset(dx, 0),
              child: child,
            );
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _phase == _RevealPhase.stats
                ? () => context.go(AppConstants.playRoute)
                : null,
            child: Container(
              color: Colors.black.withValues(alpha: 0.85),
              child: Stack(
                children: [
                  // Vignette for defeat.
                  if (_isLoser &&
                      (_phase == _RevealPhase.reveal ||
                          _phase == _RevealPhase.stats))
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment.center,
                              radius: 0.9,
                              colors: [
                                Colors.transparent,
                                AppTheme.error.withValues(alpha: 0.12),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Victory particles.
                  if (_isWinner &&
                      (_phase == _RevealPhase.reveal ||
                          _phase == _RevealPhase.stats))
                    AnimatedBuilder(
                      animation: _particleCtrl,
                      builder: (context, _) => CustomPaint(
                        size: MediaQuery.sizeOf(context),
                        painter: _ParticlePainter(
                          particles: _particles,
                          progress: _particleCtrl.value,
                        ),
                      ),
                    ),

                  // Content.
                  Center(
                    child: SingleChildScrollView(
                      padding:
                          EdgeInsets.all(Responsive.isMobile(context) ? 16 : 32),
                      child: GestureDetector(
                        onTap: () {},  // Absorb taps on the card itself.
                        child: _buildContent(context),
                      ),
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

  Widget _buildContent(BuildContext context) {
    switch (_phase) {
      case _RevealPhase.pending:
        return _buildPendingCard();
      case _RevealPhase.countdown:
        return _buildCountdownCard();
      case _RevealPhase.reveal:
      case _RevealPhase.stats:
        return _buildFullResult(context);
    }
  }

  // ── Pending ──

  Widget _buildPendingCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Blockchain graphic: 5 pulsing dots connected by lines.
          SizedBox(
            height: 48,
            child: CustomPaint(
              size: const Size(180, 48),
              painter: _BlockchainPainter(),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'MATCH COMPLETE',
            style: interStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Determining winner\u2026',
            style: interStyle(fontSize: 13, color: AppTheme.textTertiary),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.3, end: 1.0),
                duration: Duration(milliseconds: 600 + i * 200),
                curve: Curves.easeInOut,
                builder: (_, val, child) =>
                    Opacity(opacity: val, child: child),
                child: Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: const BoxDecoration(
                    color: AppTheme.solanaPurple,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Countdown ──

  Widget _buildCountdownCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 56),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'RESULTS IN',
            style: interStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textTertiary,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            key: ValueKey(_countdownValue),
            tween: Tween(begin: 1.6, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (_, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Text(
              '$_countdownValue',
              style: interStyle(
                fontSize: 72,
                fontWeight: FontWeight.w900,
                color: AppTheme.solanaPurple,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Full result ──

  Widget _buildFullResult(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isWinner = _isWinner;
    final isTie = widget.state.matchIsTie;
    final isForfeit = widget.state.matchIsForfeit;

    final isPractice = widget.state.isPracticeMode;

    final resultText = isPractice
        ? 'PRACTICE COMPLETE'
        : isTie
            ? 'DRAW'
            : isWinner
                ? 'VICTORY'
                : 'DEFEAT';

    final subtitleText = isPractice
        ? 'Solo practice session ended'
        : isForfeit
            ? (isWinner
                ? 'Opponent forfeited the match'
                : 'You forfeited the match')
            : isTie
                ? 'Both players matched ROI'
                : isWinner
                    ? 'You outperformed your opponent'
                    : 'Your opponent had better returns';

    final resultIcon = isPractice
        ? Icons.school_rounded
        : isTie
            ? Icons.balance_rounded
            : isWinner
                ? Icons.emoji_events_rounded
                : Icons.trending_down_rounded;

    return Container(
      constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 520),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _resultColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _resultColor.withValues(alpha: 0.08),
            blurRadius: 80,
            spreadRadius: 20,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Result announcement ──
          AnimatedBuilder(
            animation: _resultCtrl,
            builder: (_, child) => Opacity(
              opacity: _resultOpacity.value,
              child: Transform.scale(
                scale: _resultScale.value,
                child: child,
              ),
            ),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: isMobile ? 18 : 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _resultColor.withValues(alpha: 0.12),
                    _resultColor.withValues(alpha: 0.03),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // Icon with glow for victory.
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _resultColor.withValues(alpha: 0.12),
                      boxShadow: isWinner
                          ? [
                              BoxShadow(
                                color: _gold.withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 3,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(resultIcon, size: 28, color: _resultColor),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    resultText,
                    style: interStyle(
                      fontSize: isMobile ? 28 : 36,
                      fontWeight: FontWeight.w900,
                      color: _resultColor,
                      letterSpacing: 4,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitleText,
                    style: interStyle(
                        fontSize: 13, color: AppTheme.textTertiary),
                  ),
                ],
              ),
            ),
          ),

          // ── ROI comparison ──
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: isPractice
                ? _buildPracticeRoi()
                : _buildRoiComparison(),
          ),

          // ── Match highlights + claim + actions ──
          if (_phase == _RevealPhase.stats)
            AnimatedBuilder(
              animation: _statsCtrl,
              builder: (_, child) => Opacity(
                opacity: _statsCtrl.value,
                child: Transform.translate(
                  offset: Offset(0, _statsSlide.value),
                  child: child,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    isMobile ? 16 : 24, 0, isMobile ? 16 : 24, 0),
                child: Column(
                  children: [
                    _buildMatchHighlights(),
                    const SizedBox(height: 12),
                    if (!isPractice) ...[
                      _buildClaimSection(),
                      const SizedBox(height: 12),
                    ],
                    isPractice
                        ? _buildPracticeActions(context)
                        : _buildActionButtons(context),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Practice ROI (solo — no opponent) ──

  Widget _buildPracticeRoi() {
    final roiColor = pnlColor(_animatedMyRoi);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Text(
            'YOUR PERFORMANCE',
            style: interStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.textTertiary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            fmtPercent(_animatedMyRoi),
            style: interStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: roiColor,
              tabularFigures: true,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Return on Investment',
            style: interStyle(fontSize: 12, color: AppTheme.textTertiary),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _practiceStatChip('Balance', fmtBalance(widget.state.equity)),
              const SizedBox(width: 16),
              _practiceStatChip(
                'PnL',
                fmtPnl(widget.state.equity - widget.state.initialBalance),
                color: roiColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _practiceStatChip(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(label,
            style: interStyle(
                fontSize: 10,
                color: AppTheme.textTertiary,
                letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value,
            style: interStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color ?? AppTheme.textPrimary,
              tabularFigures: true,
            )),
      ],
    );
  }

  // ── ROI comparison ──

  Widget _buildRoiComparison() {
    final myTag = ref.read(walletProvider).gamerTag ?? 'You';
    final oppTag = widget.state.opponentGamerTag ?? 'Opponent';
    final isWinner = _isWinner;
    final isLoser = _isLoser;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Text(
            'PERFORMANCE',
            style: interStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.textTertiary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),

          // ── Visual ROI bar comparison ──
          _RoiBarComparison(
            myRoi: _animatedMyRoi,
            oppRoi: _animatedOppRoi,
          ),
          const SizedBox(height: 10),

          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _roiPlayerCard(
                    label: 'YOU',
                    tag: myTag,
                    roi: _animatedMyRoi,
                    roiColor: pnlColor(_animatedMyRoi),
                    isChampion: isWinner,
                    accentColor: isWinner ? _gold : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                          width: 1, height: 20, color: AppTheme.border),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text('VS',
                            style: interStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textTertiary,
                            )),
                      ),
                      Container(
                          width: 1, height: 20, color: AppTheme.border),
                    ],
                  ),
                ),
                Expanded(
                  child: _roiPlayerCard(
                    label: 'OPP',
                    tag: oppTag,
                    roi: _animatedOppRoi,
                    roiColor: pnlColor(_animatedOppRoi),
                    isChampion: isLoser,
                    accentColor: isLoser ? _gold : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roiPlayerCard({
    required String label,
    required String tag,
    required double roi,
    required Color roiColor,
    required bool isChampion,
    Color? accentColor,
  }) {
    return Column(
      children: [
        if (isChampion)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Icon(Icons.emoji_events_rounded,
                size: 20, color: accentColor ?? _gold),
          ),
        Text(
          label,
          style: interStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isChampion
                ? (accentColor ?? AppTheme.textTertiary)
                : AppTheme.textTertiary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tag,
          style: interStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 10),
        Text(
          fmtPercent(roi),
          style: interStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: roiColor,
            tabularFigures: true,
          ),
        ),
      ],
    );
  }

  // ── Match Highlights (replaces old stats grid) ──

  Widget _buildMatchHighlights() {
    final stats = widget.state.matchStats;
    if (stats == null || stats.totalTrades == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            const Icon(Icons.show_chart_rounded,
                size: 28, color: AppTheme.textTertiary),
            const SizedBox(height: 8),
            Text(
              'No trades were placed this match',
              style: interStyle(fontSize: 13, color: AppTheme.textTertiary),
            ),
          ],
        ),
      );
    }

    // Build highlight entries.
    final highlights = <_HighlightEntry>[];

    highlights.add(_HighlightEntry(
      icon: Icons.emoji_events_rounded,
      iconColor: _gold,
      label: 'Best Trade',
      value: '${fmtPnl(stats.bestTradePnl)} on ${stats.bestTradeAsset ?? '?'}',
      valueColor: AppTheme.success,
    ));

    if (stats.worstTradePnl < 0) {
      highlights.add(_HighlightEntry(
        icon: Icons.dangerous_rounded,
        iconColor: AppTheme.error,
        label: 'Worst Trade',
        value:
            '${fmtPnl(stats.worstTradePnl)} on ${stats.worstTradeAsset ?? '?'}',
        valueColor: AppTheme.error,
      ));
    }

    if (stats.hotStreak > 1) {
      highlights.add(_HighlightEntry(
        icon: Icons.local_fire_department_rounded,
        iconColor: const Color(0xFFFF6B35),
        label: 'Win Streak',
        value: '${stats.hotStreak} consecutive wins',
        valueColor: const Color(0xFFFF6B35),
      ));
    }

    if (stats.leadChanges > 0) {
      highlights.add(_HighlightEntry(
        icon: Icons.swap_horiz_rounded,
        iconColor: AppTheme.solanaPurple,
        label: 'Lead Changes',
        value: '${stats.leadChanges} times',
      ));
    }

    highlights.add(_HighlightEntry(
      icon: Icons.swap_vert_rounded,
      iconColor: AppTheme.textSecondary,
      label: 'Total Trades',
      value:
          '${stats.totalTrades} (${stats.winRate.toStringAsFixed(0)}% win rate)',
    ));

    highlights.add(_HighlightEntry(
      icon: Icons.bar_chart_rounded,
      iconColor: AppTheme.info,
      label: 'Volume',
      value: '${fmtBalance(stats.totalVolume)} notional',
    ));

    // Cap at 4 highlights to keep the card compact.
    if (highlights.length > 4) {
      highlights.removeRange(4, highlights.length);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 14, color: AppTheme.textTertiary),
              const SizedBox(width: 6),
              Text(
                'MATCH HIGHLIGHTS',
                style: interStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textTertiary,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(height: 1, color: AppTheme.border),
          const SizedBox(height: 8),

          // Staggered highlight rows.
          ...List.generate(highlights.length, (i) {
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 300 + i * 80),
              curve: Curves.easeOut,
              builder: (_, val, child) {
                return Opacity(
                  opacity: val,
                  child: Transform.translate(
                    offset: Offset(12 * (1 - val), 0),
                    child: child,
                  ),
                );
              },
              child: _HighlightRow(entry: highlights[i]),
            );
          }),
        ],
      ),
    );
  }

  // ── Payout section (instant balance update) ──

  Widget _buildClaimSection() {
    final isWinner = _isWinner;
    final isTie = widget.state.matchIsTie;

    if (isTie) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.textTertiary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.balance_rounded,
                size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Draw — bet refunded to your balance',
                style:
                    interStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    if (!isWinner) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.error.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.remove_circle_outline_rounded,
                size: 16, color: AppTheme.error.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Bet deducted from your balance',
                style: interStyle(
                    fontSize: 12,
                    color: AppTheme.error.withValues(alpha: 0.7)),
              ),
            ),
          ],
        ),
      );
    }

    // Winner — instant payout
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppTheme.success.withValues(alpha: 0.12),
          AppTheme.success.withValues(alpha: 0.05),
        ]),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 18, color: AppTheme.success),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Prize credited to your balance instantly!',
              style: interStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.success),
            ),
          ),
        ],
      ),
    );
  }

  // ── Action buttons ──

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        // Play Again — primary CTA.
        Expanded(
          child: SizedBox(
            height: 48,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => context.go(AppConstants.playRoute),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.purpleGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color:
                            AppTheme.solanaPurple.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isLoser
                              ? Icons.replay_rounded
                              : Icons.sports_esports_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isLoser ? 'Rematch' : 'Play Again',
                          style: interStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Share.
        SizedBox(
          width: 48,
          height: 48,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _shareResult,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Center(
                  child: Icon(Icons.share_rounded,
                      size: 18, color: AppTheme.textSecondary),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Practice action buttons ──

  Widget _buildPracticeActions(BuildContext context) {
    return Row(
      children: [
        // Practice Again.
        Expanded(
          child: SizedBox(
            height: 48,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  // Re-enter practice with same duration.
                  final d = widget.state.totalDurationSeconds;
                  context.go('/arena?d=$d&bet=0&practice=true');
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.warning.withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.replay_rounded,
                            size: 16, color: AppTheme.warning),
                        const SizedBox(width: 8),
                        Text(
                          'Practice Again',
                          style: interStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.warning),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Enter Arena (real match).
        Expanded(
          child: SizedBox(
            height: 48,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => context.go(AppConstants.playRoute),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.purpleGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color:
                            AppTheme.solanaPurple.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded,
                            size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Enter Arena',
                          style: interStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _shareResult() {
    final myTag =
        ref.read(walletProvider).gamerTag ?? 'You';
    final oppTag = widget.state.opponentGamerTag ?? 'Opponent';

    showShareCardDialog(
      context,
      ShareCardData(
        isWinner: _isWinner,
        isTie: widget.state.matchIsTie,
        myRoi: _myRoi,
        oppRoi: _oppRoi,
        myTag: myTag,
        oppTag: oppTag,
        durationSeconds: widget.state.totalDurationSeconds,
        betAmount: widget.betAmount,
        stats: widget.state.matchStats,
      ),
    );
  }
}

// =============================================================================
// Highlight Entry model + row widget
// =============================================================================

class _HighlightEntry {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;

  const _HighlightEntry({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
  });
}

class _HighlightRow extends StatelessWidget {
  final _HighlightEntry entry;

  const _HighlightRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: entry.iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(entry.icon, size: 14, color: entry.iconColor),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              entry.label,
              style: interStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              entry.value,
              style: interStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: entry.valueColor ?? AppTheme.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// ROI Bar Comparison — visual bar chart showing ROI side-by-side
// =============================================================================

class _RoiBarComparison extends StatelessWidget {
  final double myRoi;
  final double oppRoi;

  const _RoiBarComparison({required this.myRoi, required this.oppRoi});

  @override
  Widget build(BuildContext context) {
    final maxRoi = [myRoi.abs(), oppRoi.abs(), 1.0].reduce(math.max);
    final myWidth = (myRoi.abs() / maxRoi).clamp(0.05, 1.0);
    final oppWidth = (oppRoi.abs() / maxRoi).clamp(0.05, 1.0);

    return Row(
      children: [
        // My ROI bar.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FractionallySizedBox(
                widthFactor: myWidth,
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  height: 8,
                  decoration: BoxDecoration(
                    color: pnlColor(myRoi),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: pnlColor(myRoi).withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Opponent ROI bar.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FractionallySizedBox(
                widthFactor: oppWidth,
                alignment: Alignment.centerRight,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  height: 8,
                  decoration: BoxDecoration(
                    color: pnlColor(oppRoi),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: pnlColor(oppRoi).withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Blockchain Graphic Painter — Animated dots connected by lines (pending phase)
// =============================================================================

class _BlockchainPainter extends CustomPainter {
  _BlockchainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const nodeCount = 5;
    final spacing = size.width / (nodeCount + 1);
    final cy = size.height / 2;
    final nodes = <Offset>[];

    for (int i = 0; i < nodeCount; i++) {
      nodes.add(Offset(spacing * (i + 1), cy));
    }

    // Draw connecting lines.
    linePaint.color = AppTheme.solanaPurple.withValues(alpha: 0.3);
    for (int i = 0; i < nodes.length - 1; i++) {
      canvas.drawLine(nodes[i], nodes[i + 1], linePaint);
    }

    // Draw nodes.
    for (int i = 0; i < nodes.length; i++) {
      // Outer glow.
      paint.color = AppTheme.solanaPurple.withValues(alpha: 0.1);
      canvas.drawCircle(nodes[i], 10, paint);
      // Inner circle.
      paint.color = AppTheme.solanaPurple.withValues(alpha: 0.6);
      canvas.drawCircle(nodes[i], 5, paint);
      // Center dot.
      paint.color = AppTheme.solanaPurple;
      canvas.drawCircle(nodes[i], 2.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =============================================================================
// Particle system for victory celebration
// =============================================================================

class _Particle {
  double x, y, vx, vy, size, rotation;
  Color color;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.rotation,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final px = (p.x + p.vx * progress) * size.width;
      final py = (p.y + p.vy * progress) * size.height;

      // Fade out over time.
      final opacity = (1.0 - progress).clamp(0.0, 1.0) * 0.8;
      if (opacity <= 0) continue;

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity);

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rotation + progress * 4);

      // Draw small rectangle confetti.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.6),
          const Radius.circular(1),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}
