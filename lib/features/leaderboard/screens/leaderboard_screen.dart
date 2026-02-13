import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../models/leaderboard_models.dart';
import '../providers/leaderboard_provider.dart';

/// Leaderboard screen — gradient hero with top-3 podium + rankings table.
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  static const _periods = ['Weekly', 'Monthly', 'All Time'];
  static const _timeframes = ['All', '15m', '1h', '4h', '12h', '24h'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(leaderboardProvider);
    final wallet = ref.watch(walletProvider);
    final isMobile = Responsive.isMobile(context);

    // Top 3 for podium
    final top3 = state.players.take(3).toList();
    final rest = state.players.length > 3
        ? state.players.sublist(3)
        : <LeaderboardPlayer>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),

          // ── Hero with podium ──────────────────────────────────────
          Padding(
            padding: Responsive.horizontalPadding(context),
            child: _LeaderboardHero(
              top3: top3,
              isMobile: isMobile,
            ),
          ),
          const SizedBox(height: 24),

          // ── Filters ───────────────────────────────────────────────
          Padding(
            padding: Responsive.horizontalPadding(context),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _FilterChipGroup(
                  options: _periods,
                  selected: state.selectedPeriod,
                  onSelected: (v) =>
                      ref.read(leaderboardProvider.notifier).filterByPeriod(v),
                ),
                _FilterChipGroup(
                  options: _timeframes,
                  selected: state.selectedTimeframe,
                  onSelected: (v) => ref
                      .read(leaderboardProvider.notifier)
                      .filterByTimeframe(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Table header ──────────────────────────────────────────
          Padding(
            padding: Responsive.horizontalPadding(context),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusLg),
                ),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  _HeaderCell('#', width: 48),
                  Expanded(child: _HeaderCell('Player')),
                  _HeaderCell('Wins', width: 80),
                  if (!isMobile) _HeaderCell('Win Rate', width: 90),
                  if (!isMobile) _HeaderCell('Games', width: 70),
                  _HeaderCell('PnL', width: 100),
                  if (!isMobile) _HeaderCell('Streak', width: 70),
                ],
              ),
            ),
          ),

          // ── Table rows (4th place onward) ─────────────────────────
          Padding(
            padding: Responsive.horizontalPadding(context),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(AppTheme.radiusLg),
                ),
                border: Border.all(color: AppTheme.border),
              ),
              child: state.isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : rest.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'More players coming soon...',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                          ),
                        )
                      : Column(
                          children: List.generate(rest.length, (i) {
                            final player = rest[i];
                            final isCurrentUser =
                                wallet.gamerTag != null &&
                                    wallet.gamerTag == player.gamerTag;
                            return _LeaderboardRow(
                              rank: i + 4,
                              player: player,
                              isMobile: isMobile,
                              isCurrentUser: isCurrentUser,
                            );
                          }),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Leaderboard Hero — gradient card with top 3 podium
// ═══════════════════════════════════════════════════════════════════════════════

class _LeaderboardHero extends StatelessWidget {
  final List<LeaderboardPlayer> top3;
  final bool isMobile;

  const _LeaderboardHero({required this.top3, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1D2E), Color(0xFF251845), Color(0xFF351F72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppTheme.solanaPurple.withValues(alpha: 0.12),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative glow
          Positioned(
            top: -50,
            left: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFD700).withValues(alpha: 0.08),
                    const Color(0xFFFFD700).withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            right: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.solanaPurple.withValues(alpha: 0.15),
                    AppTheme.solanaPurple.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.all(isMobile ? 24 : 32),
            child: Column(
              children: [
                // Title
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Leaderboard',
                          style: GoogleFonts.inter(
                            fontSize: isMobile ? 22 : 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Top fighters in the arena',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Icon(
                        Icons.emoji_events_rounded,
                        color: const Color(0xFFFFD700),
                        size: isMobile ? 22 : 28,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: isMobile ? 28 : 36),

                // Podium
                if (top3.length >= 3)
                  _Podium(top3: top3, isMobile: isMobile),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Podium — 2nd | 1st | 3rd layout
// ═══════════════════════════════════════════════════════════════════════════════

class _Podium extends StatelessWidget {
  final List<LeaderboardPlayer> top3;
  final bool isMobile;
  const _Podium({required this.top3, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 2nd place
        Expanded(
          child: _PodiumSlot(
            player: top3[1],
            rank: 2,
            color: const Color(0xFFC0C0C0),
            height: isMobile ? 80 : 100,
            isMobile: isMobile,
          ),
        ),
        const SizedBox(width: 8),
        // 1st place
        Expanded(
          child: _PodiumSlot(
            player: top3[0],
            rank: 1,
            color: const Color(0xFFFFD700),
            height: isMobile ? 110 : 130,
            isMobile: isMobile,
          ),
        ),
        const SizedBox(width: 8),
        // 3rd place
        Expanded(
          child: _PodiumSlot(
            player: top3[2],
            rank: 3,
            color: const Color(0xFFCD7F32),
            height: isMobile ? 65 : 80,
            isMobile: isMobile,
          ),
        ),
      ],
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  final LeaderboardPlayer player;
  final int rank;
  final Color color;
  final double height;
  final bool isMobile;

  const _PodiumSlot({
    required this.player,
    required this.rank,
    required this.color,
    required this.height,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Name + Wins
        Text(
          player.gamerTag,
          style: GoogleFonts.inter(
            fontSize: rank == 1 ? 14 : 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          '${player.wins}W ${player.losses}L',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 10),

        // Pedestal
        Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.25),
                color.withValues(alpha: 0.08),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border(
              top: BorderSide(color: color.withValues(alpha: 0.5), width: 2),
              left: BorderSide(
                  color: color.withValues(alpha: 0.15), width: 1),
              right: BorderSide(
                  color: color.withValues(alpha: 0.15), width: 1),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.emoji_events_rounded,
                color: color,
                size: rank == 1 ? 32 : 24,
              ),
              const SizedBox(height: 6),
              Text(
                rank == 1
                    ? '1st'
                    : rank == 2
                        ? '2nd'
                        : '3rd',
                style: GoogleFonts.inter(
                  fontSize: rank == 1 ? 16 : 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(height: 4),
                Text(
                  '+\$${player.pnl.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Filter Chips ─────────────────────────────────────────────────────────────

class _FilterChipGroup extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const _FilterChipGroup({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((option) {
          final isSelected = option == selected;
          return GestureDetector(
            onTap: () => onSelected(option),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color:
                    isSelected ? AppTheme.solanaPurple : Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Text(
                option,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color:
                      isSelected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Header Cell ──────────────────────────────────────────────────────────────

class _HeaderCell extends StatelessWidget {
  final String label;
  final double? width;
  const _HeaderCell(this.label, {this.width});

  @override
  Widget build(BuildContext context) {
    final child = Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppTheme.textTertiary,
        letterSpacing: 0.5,
      ),
    );
    return width != null ? SizedBox(width: width, child: child) : child;
  }
}

// ── Leaderboard Row ──────────────────────────────────────────────────────────

class _LeaderboardRow extends StatefulWidget {
  final int rank;
  final LeaderboardPlayer player;
  final bool isMobile;
  final bool isCurrentUser;

  const _LeaderboardRow({
    required this.rank,
    required this.player,
    required this.isMobile,
    this.isCurrentUser = false,
  });

  @override
  State<_LeaderboardRow> createState() => _LeaderboardRowState();
}

class _LeaderboardRowState extends State<_LeaderboardRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.player;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: widget.isCurrentUser
              ? AppTheme.solanaPurple.withValues(alpha: 0.06)
              : _hovered
                  ? AppTheme.solanaPurple.withValues(alpha: 0.03)
                  : null,
          border: widget.isCurrentUser
              ? Border(
                  left: BorderSide(
                      color: AppTheme.solanaPurple, width: 3),
                )
              : null,
        ),
        child: Row(
          children: [
            // Rank
            SizedBox(
              width: 48,
              child: Text(
                '${widget.rank}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textTertiary,
                ),
              ),
            ),

            // Player
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      p.gamerTag,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: widget.isCurrentUser
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: widget.isCurrentUser
                            ? AppTheme.solanaPurple
                            : AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.isCurrentUser) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            AppTheme.solanaPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'YOU',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.solanaPurple,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Wins
            SizedBox(
              width: 80,
              child: Text(
                '${p.wins}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),

            // Win Rate
            if (!widget.isMobile)
              SizedBox(
                width: 90,
                child: Text(
                  '${p.winRate.toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),

            // Games
            if (!widget.isMobile)
              SizedBox(
                width: 70,
                child: Text(
                  '${p.gamesPlayed}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),

            // PnL
            SizedBox(
              width: 100,
              child: Text(
                '${p.pnl >= 0 ? '+' : ''}\$${p.pnl.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: p.pnl >= 0 ? AppTheme.success : AppTheme.error,
                ),
              ),
            ),

            // Streak
            if (!widget.isMobile)
              SizedBox(
                width: 70,
                child: p.streak > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${p.streak}W',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.warning,
                          ),
                        ),
                      )
                    : Text(
                        '-',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textTertiary,
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
