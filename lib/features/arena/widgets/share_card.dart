import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;

import '../../../core/theme/app_theme.dart';
import '../models/trading_models.dart';
import '../utils/arena_helpers.dart';

// =============================================================================
// Share Card — Shareable match result image for social media
// =============================================================================

/// Data needed to render the share card.
class ShareCardData {
  final bool isWinner;
  final bool isTie;
  final double myRoi;
  final double oppRoi;
  final String myTag;
  final String oppTag;
  final int durationSeconds;
  final double betAmount;
  final MatchStats? stats;

  const ShareCardData({
    required this.isWinner,
    required this.isTie,
    required this.myRoi,
    required this.oppRoi,
    required this.myTag,
    required this.oppTag,
    required this.durationSeconds,
    required this.betAmount,
    this.stats,
  });
}

/// Shows a dialog with the rendered share card and share options.
void showShareCardDialog(BuildContext context, ShareCardData data) {
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => _ShareCardDialog(data: data),
  );
}

// =============================================================================
// Dialog
// =============================================================================

class _ShareCardDialog extends StatefulWidget {
  final ShareCardData data;

  const _ShareCardDialog({required this.data});

  @override
  State<_ShareCardDialog> createState() => _ShareCardDialogState();
}

class _ShareCardDialogState extends State<_ShareCardDialog> {
  final _repaintKey = GlobalKey();
  bool _capturing = false;

  Future<void> _captureAndDownload() async {
    setState(() => _capturing = true);
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final base64 = base64Encode(byteData.buffer.asUint8List());
      final dataUrl = 'data:image/png;base64,$base64';

      // Trigger browser download.
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
      anchor.href = dataUrl;
      anchor.download = 'solfight-result.png';
      anchor.click();
    } catch (_) {
      // Silently fail.
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _shareToTwitter() {
    final d = widget.data;
    final result = d.isTie
        ? 'Drew'
        : d.isWinner
            ? 'Won'
            : 'Lost';
    final roiStr =
        '${d.myRoi >= 0 ? '+' : ''}${d.myRoi.toStringAsFixed(2)}%';

    final text =
        'Just $result a SolFight match with $roiStr ROI vs ${d.oppTag}!\n\n'
        'Play at solfight.io';

    final url = Uri.parse(
        'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(text)}');
    launchUrl(url, mode: LaunchMode.externalApplication);
  }

  void _shareToTelegram() {
    final d = widget.data;
    final result = d.isTie
        ? 'Drew'
        : d.isWinner
            ? 'Won'
            : 'Lost';
    final roiStr =
        '${d.myRoi >= 0 ? '+' : ''}${d.myRoi.toStringAsFixed(2)}%';

    final text =
        'Just $result a SolFight match with $roiStr ROI! Play at solfight.io';

    final url = Uri.parse(
        'https://t.me/share/url?url=${Uri.encodeComponent('https://solfight.io')}&text=${Uri.encodeComponent(text)}');
    launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Card preview.
            RepaintBoundary(
              key: _repaintKey,
              child: _ShareCardContent(data: widget.data),
            ),

            const SizedBox(height: 20),

            // Share buttons.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Row(
                children: [
                  // Download.
                  Expanded(
                    child: _ShareButton(
                      icon: Icons.download_rounded,
                      label: 'Save Image',
                      color: AppTheme.solanaPurple,
                      loading: _capturing,
                      onTap: _captureAndDownload,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Twitter/X.
                  Expanded(
                    child: _ShareButton(
                      icon: Icons.alternate_email_rounded,
                      label: 'Post to X',
                      color: const Color(0xFF1DA1F2),
                      onTap: _shareToTwitter,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Telegram.
                  Expanded(
                    child: _ShareButton(
                      icon: Icons.send_rounded,
                      label: 'Telegram',
                      color: const Color(0xFF0088CC),
                      onTap: _shareToTelegram,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Close.
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close',
                  style: interStyle(
                      fontSize: 13, color: AppTheme.textTertiary)),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Share Card Content — The visual card that gets captured as an image
// =============================================================================

class _ShareCardContent extends StatelessWidget {
  final ShareCardData data;

  const _ShareCardContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final isWinner = data.isWinner;
    final isTie = data.isTie;
    final resultColor = isTie
        ? AppTheme.textSecondary
        : isWinner
            ? const Color(0xFFFFD700)
            : AppTheme.error;
    final resultText = isTie
        ? 'DRAW'
        : isWinner
            ? 'VICTORY'
            : 'DEFEAT';
    final resultIcon = isTie
        ? Icons.balance_rounded
        : isWinner
            ? Icons.emoji_events_rounded
            : Icons.trending_down_rounded;

    return Container(
      width: 400,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: resultColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: resultColor.withValues(alpha: 0.15),
            blurRadius: 40,
            spreadRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header with logo ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.solanaPurple.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                // Logo.
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    image: const DecorationImage(
                      image: AssetImage('assets/logo.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'SolFight',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Text(
                  '1v1 Trading Arena',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
          ),

          // ── Result banner ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  resultColor.withValues(alpha: 0.12),
                  resultColor.withValues(alpha: 0.03),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                Icon(resultIcon, size: 32, color: resultColor),
                const SizedBox(height: 8),
                Text(
                  resultText,
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: resultColor,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 6),
                // Large ROI.
                Text(
                  fmtPercent(data.myRoi),
                  style: GoogleFonts.inter(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: pnlColor(data.myRoi),
                    height: 1.1,
                  ),
                ),
                Text(
                  'ROI',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white38,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),

          // ── Matchup info ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TagBadge(tag: data.myTag, color: AppTheme.solanaPurple),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('vs',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.white30)),
                ),
                _TagBadge(
                    tag: data.oppTag, color: const Color(0xFFFF6B35)),
              ],
            ),
          ),

          // ── Match details row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _DetailChip(
                  icon: Icons.timer_outlined,
                  label: _formatDuration(data.durationSeconds),
                ),
                const SizedBox(width: 10),
                _DetailChip(
                  icon: Icons.toll_rounded,
                  label: '\$${data.betAmount.toStringAsFixed(0)} USDC',
                ),
                if (data.stats != null && data.stats!.totalTrades > 0) ...[
                  const SizedBox(width: 10),
                  _DetailChip(
                    icon: Icons.swap_vert_rounded,
                    label:
                        '${data.stats!.totalTrades} trades',
                  ),
                ],
              ],
            ),
          ),

          // ── Key stats ──
          if (data.stats != null && data.stats!.totalTrades > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: _buildStats(data.stats!),
            ),

          // ── Footer ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 1,
                  width: 40,
                  color: Colors.white10,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'solfight.io',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.solanaPurple.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                Container(
                  height: 1,
                  width: 40,
                  color: Colors.white10,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(MatchStats stats) {
    final items = <_StatItem>[];

    if (stats.bestTradePnl > 0) {
      items.add(_StatItem(
        label: 'Best Trade',
        value: '${fmtPnl(stats.bestTradePnl)} ${stats.bestTradeAsset ?? ''}',
        color: AppTheme.success,
      ));
    }

    items.add(_StatItem(
      label: 'Win Rate',
      value: '${stats.winRate.toStringAsFixed(0)}%',
      color: stats.winRate >= 50 ? AppTheme.success : AppTheme.error,
    ));

    if (stats.hotStreak > 1) {
      items.add(_StatItem(
        label: 'Streak',
        value: '${stats.hotStreak}x',
        color: const Color(0xFFFF6B35),
      ));
    }

    items.add(_StatItem(
      label: 'Volume',
      value: fmtBalance(stats.totalVolume),
    ));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items,
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds >= 3600) return '${seconds ~/ 3600}h';
    return '${seconds ~/ 60}m';
  }
}

// =============================================================================
// Helper widgets
// =============================================================================

class _TagBadge extends StatelessWidget {
  final String tag;
  final Color color;

  const _TagBadge({required this.tag, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        tag,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white30),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatItem({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color ?? Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 9, color: Colors.white38),
        ),
      ],
    );
  }
}

class _ShareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  const _ShareButton({
    required this.icon,
    required this.label,
    required this.color,
    this.loading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: loading ? null : onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: loading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 15, color: color),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
