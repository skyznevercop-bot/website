import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../features/wallet/providers/wallet_provider.dart';
import '../../../features/wallet/widgets/connect_wallet_modal.dart';
import '../models/clan_models.dart';
import '../providers/clan_provider.dart';
import '../widgets/create_clan_modal.dart';

// ── Colors ─────────────────────────────────────────────────────────────────
const _gold = Color(0xFFFFD700);
const _goldDark = Color(0xFFD4A800);
const _goldDim = Color(0xFFB8860B);
const _warRed = Color(0xFFFF4444);
const _warOrange = Color(0xFFFF8C00);

/// Clan screen — Clash Royale-inspired clan hub.
class ClanScreen extends ConsumerWidget {
  const ClanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(clanProvider);
    final wallet = ref.watch(walletProvider);
    final isConnected = wallet.isConnected;
    final isMobile = Responsive.isMobile(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),

          // ── Clan Banner / Hero ─────────────────────────────────────
          if (!isConnected)
            Padding(
              padding: Responsive.horizontalPadding(context),
              child: _ConnectWalletBanner(isMobile: isMobile),
            )
          else if (state.hasClan)
            Padding(
              padding: Responsive.horizontalPadding(context),
              child: _MyClanBanner(
                clan: state.userClan!,
                isMobile: isMobile,
                ref: ref,
              ),
            )
          else
            Padding(
              padding: Responsive.horizontalPadding(context),
              child: _NoClanBanner(isMobile: isMobile),
            ),

          const SizedBox(height: 24),

          // ── Clan War Status (only when in clan) ────────────────────
          if (isConnected && state.hasClan) ...[
            Padding(
              padding: Responsive.horizontalPadding(context),
              child: _ClanWarBanner(
                clan: state.userClan!,
                isMobile: isMobile,
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Members Section (only when in clan) ────────────────────
          if (isConnected && state.hasClan && state.userClan!.members.isNotEmpty) ...[
            Padding(
              padding: Responsive.horizontalPadding(context),
              child: _SectionHeader(
                title: 'Members',
                trailing: '${state.userClan!.memberCount}/${state.userClan!.maxMembers}',
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: Responsive.horizontalPadding(context),
              child: _MembersList(
                members: state.userClan!.members,
                isMobile: isMobile,
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── War Log (only when in clan with war history) ───────────
          if (isConnected && state.hasClan && state.userClan!.warLog.isNotEmpty) ...[
            Padding(
              padding: Responsive.horizontalPadding(context),
              child: _SectionHeader(
                title: 'War Log',
                trailing: '${state.userClan!.clanWarWins} wins',
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: Responsive.horizontalPadding(context),
              child: _WarLog(warLog: state.userClan!.warLog),
            ),
            const SizedBox(height: 24),
          ],

          // ── Browse Clans ───────────────────────────────────────────
          Padding(
            padding: Responsive.horizontalPadding(context),
            child: Row(
              children: [
                Expanded(
                  child: _SectionHeader(
                    title: 'Find a Clan',
                    trailing: '${state.browseClansList.length} clans',
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      ref.read(clanProvider.notifier).loadClans(),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  color: AppTheme.textTertiary,
                  splashRadius: 18,
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: Responsive.horizontalPadding(context),
            child: _SearchBar(
              onChanged: (q) => ref.read(clanProvider.notifier).searchClans(q),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: Responsive.horizontalPadding(context),
            child: state.isLoading
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.solanaPurple,
                        ),
                      ),
                    ),
                  )
                : state.browseClansList.isEmpty
                    ? _EmptyState()
                    : Column(
                        children: [
                          for (int i = 0; i < state.browseClansList.length; i++)
                            _ClanCard(
                              rank: i + 1,
                              clan: state.browseClansList[i],
                              canJoin: isConnected && !state.hasClan,
                              isMobile: isMobile,
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Section Header
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Accent bar
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_gold, _goldDim],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: _gold.withValues(alpha: 0.3),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _gold.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: _gold.withValues(alpha: 0.05),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Text(
              trailing!,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _gold,
              ),
            ),
          ),
        ],
        const Spacer(),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// My Clan Banner — the big Clash Royale-style clan card
// ═══════════════════════════════════════════════════════════════════════════════

class _MyClanBanner extends StatelessWidget {
  final Clan clan;
  final bool isMobile;
  final WidgetRef ref;

  const _MyClanBanner({
    required this.clan,
    required this.isMobile,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1520), Color(0xFF2E1A50), Color(0xFF1A2035)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.1),
            blurRadius: 40,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppTheme.solanaPurple.withValues(alpha: 0.06),
            blurRadius: 60,
            spreadRadius: -5,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background pattern — subtle diagonal lines
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CustomPaint(painter: _DiagonalPatternPainter()),
            ),
          ),
          // Gold glow top-center
          Positioned(
            top: -80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _gold.withValues(alpha: 0.12),
                      _gold.withValues(alpha: 0.04),
                      _gold.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.4, 1],
                  ),
                ),
              ),
            ),
          ),
          // Purple glow bottom-right
          Positioned(
            bottom: -40,
            right: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.solanaPurple.withValues(alpha: 0.08),
                    AppTheme.solanaPurple.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.all(isMobile ? 20 : 28),
            child: Column(
              children: [
                // ── Top Row: Shield + Name + Level ──────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Clan Shield
                    _ClanShield(level: clan.level, size: isMobile ? 60 : 72),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  clan.name,
                                  style: GoogleFonts.inter(
                                    fontSize: isMobile ? 20 : 24,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _gold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: _gold.withValues(alpha: 0.25)),
                                ),
                                child: Text(
                                  clan.tag,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: _gold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (clan.description.isNotEmpty)
                            Text(
                              clan.description,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.4),
                                height: 1.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 8),
                          // Trophy count
                          Row(
                            children: [
                              Icon(Icons.emoji_events_rounded,
                                  size: 16, color: _gold),
                              const SizedBox(width: 4),
                              Text(
                                _formatNumber(clan.trophies),
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: _gold,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(Icons.military_tech_rounded,
                                  size: 16,
                                  color: Colors.white.withValues(alpha: 0.4)),
                              const SizedBox(width: 4),
                              Text(
                                'Lv. ${clan.level}',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Leave button
                    _LeaveButton(
                      onTap: () => ref.read(clanProvider.notifier).leaveClan(),
                    ),
                  ],
                ),

                SizedBox(height: isMobile ? 18 : 24),

                // ── Stats Grid ──────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.04),
                        _gold.withValues(alpha: 0.02),
                        Colors.white.withValues(alpha: 0.04),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _gold.withValues(alpha: 0.08),
                    ),
                  ),
                  child: isMobile
                      ? Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _buildStats(),
                        )
                      : Row(
                          children: _buildStats()
                              .map((w) => Expanded(child: w))
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStats() {
    return [
      _StatItem(
        icon: Icons.people_rounded,
        iconColor: AppTheme.solanaPurple,
        label: 'Members',
        value: '${clan.memberCount}/${clan.maxMembers}',
      ),
      _StatItem(
        icon: Icons.local_fire_department_rounded,
        iconColor: _warOrange,
        label: 'War Wins',
        value: '${clan.clanWarWins}',
      ),
      _StatItem(
        icon: Icons.trending_up_rounded,
        iconColor: AppTheme.solanaGreen,
        label: 'Win Rate',
        value: '${clan.winRate}%',
      ),
      _StatItem(
        icon: Icons.shield_rounded,
        iconColor: _gold,
        label: 'Record',
        value: '${clan.totalWins}W ${clan.totalLosses}L',
      ),
    ];
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Clan Shield — the emblem with level ring
// ═══════════════════════════════════════════════════════════════════════════════

class _ClanShield extends StatelessWidget {
  final int level;
  final double size;
  const _ClanShield({required this.level, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _gold.withValues(alpha: 0.25),
            AppTheme.solanaPurple.withValues(alpha: 0.35),
            _gold.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0, 0.6, 1],
        ),
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(color: _gold.withValues(alpha: 0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppTheme.solanaPurple.withValues(alpha: 0.1),
            blurRadius: 30,
            spreadRadius: -2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.shield_rounded,
            size: size * 0.5,
            color: _gold,
          ),
          Positioned(
            bottom: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1520),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _gold.withValues(alpha: 0.4)),
              ),
              child: Text(
                '$level',
                style: GoogleFonts.inter(
                  fontSize: size * 0.14,
                  fontWeight: FontWeight.w900,
                  color: _gold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Stat Item — icon + value + label
// ═══════════════════════════════════════════════════════════════════════════════

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: iconColor.withValues(alpha: 0.06)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.15),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(icon, size: 15, color: iconColor),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Clan War Banner
// ═══════════════════════════════════════════════════════════════════════════════

class _ClanWarBanner extends StatelessWidget {
  final Clan clan;
  final bool isMobile;
  const _ClanWarBanner({required this.clan, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    if (!clan.isWarActive) {
      // No active war — subtle card
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.textTertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.shield_outlined,
                  size: 20, color: AppTheme.textTertiary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Active Clan War',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    'Start a war to battle other clans for trophies',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            _ActionChip(label: 'Start War', color: AppTheme.solanaPurple),
          ],
        ),
      );
    }

    // Active war — fiery banner
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF351010), Color(0xFF451818), Color(0xFF351010)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _warRed.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _warRed.withValues(alpha: 0.12),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: _warOrange.withValues(alpha: 0.06),
            blurRadius: 50,
            spreadRadius: -5,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Fire glow left
          Positioned(
            left: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _warOrange.withValues(alpha: 0.15),
                    _warOrange.withValues(alpha: 0.05),
                    _warOrange.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.4, 1],
                ),
              ),
            ),
          ),
          // Fire glow right
          Positioned(
            right: -20,
            bottom: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _warRed.withValues(alpha: 0.12),
                    _warRed.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          // Center fire glow
          Positioned(
            left: 0,
            right: 0,
            top: -20,
            child: Center(
              child: Container(
                width: 200,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(40),
                  gradient: RadialGradient(
                    colors: [
                      _warOrange.withValues(alpha: 0.06),
                      _warOrange.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _warRed.withValues(alpha: 0.3),
                        _warOrange.withValues(alpha: 0.2),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _warOrange.withValues(alpha: 0.35)),
                    boxShadow: [
                      BoxShadow(
                        color: _warOrange.withValues(alpha: 0.2),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.local_fire_department_rounded,
                    size: 22,
                    color: _warOrange,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'CLAN WAR',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: _warOrange,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _PulsingDot(color: _warRed),
                          const SizedBox(width: 4),
                          Text(
                            'ACTIVE',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _warRed,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Battle in progress — fight for your clan!',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
                _ActionChip(label: 'Battle', color: _warRed),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Pulsing Dot — animated war indicator
// ═══════════════════════════════════════════════════════════════════════════════

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: 0.5 + _controller.value * 0.5),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: _controller.value * 0.4),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Action Chip — small CTA button
// ═══════════════════════════════════════════════════════════════════════════════

class _ActionChip extends StatefulWidget {
  final String label;
  final Color color;
  const _ActionChip({required this.label, required this.color});

  @override
  State<_ActionChip> createState() => _ActionChipState();
}

class _ActionChipState extends State<_ActionChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: _hovered
              ? widget.color.withValues(alpha: 0.25)
              : widget.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: widget.color.withValues(alpha: _hovered ? 0.5 : 0.2),
          ),
        ),
        child: Text(
          widget.label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _hovered ? Colors.white : widget.color,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Members List
// ═══════════════════════════════════════════════════════════════════════════════

class _MembersList extends StatelessWidget {
  final List<ClanMember> members;
  final bool isMobile;
  const _MembersList({required this.members, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: List.generate(members.length, (i) {
          final m = members[i];
          return _MemberRow(
            member: m,
            isLast: i == members.length - 1,
            isMobile: isMobile,
          );
        }),
      ),
    );
  }
}

class _MemberRow extends StatefulWidget {
  final ClanMember member;
  final bool isLast;
  final bool isMobile;
  const _MemberRow({
    required this.member,
    required this.isLast,
    required this.isMobile,
  });

  @override
  State<_MemberRow> createState() => _MemberRowState();
}

class _MemberRowState extends State<_MemberRow> {
  bool _hovered = false;

  IconData _roleIcon(ClanRole role) {
    switch (role) {
      case ClanRole.leader:
        return Icons.star_rounded;
      case ClanRole.coLeader:
        return Icons.star_half_rounded;
      case ClanRole.elder:
        return Icons.shield_rounded;
      case ClanRole.member:
        return Icons.person_rounded;
    }
  }

  Color _roleColor(ClanRole role) {
    switch (role) {
      case ClanRole.leader:
        return _gold;
      case ClanRole.coLeader:
        return AppTheme.solanaPurple;
      case ClanRole.elder:
        return AppTheme.info;
      case ClanRole.member:
        return AppTheme.textTertiary;
    }
  }

  String _roleLabel(ClanRole role) {
    switch (role) {
      case ClanRole.leader:
        return 'Leader';
      case ClanRole.coLeader:
        return 'Co-Leader';
      case ClanRole.elder:
        return 'Elder';
      case ClanRole.member:
        return 'Member';
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final roleColor = _roleColor(m.role);
    final isHighRank =
        m.role == ClanRole.leader || m.role == ClanRole.coLeader;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: widget.isMobile ? 14 : 18,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          gradient: isHighRank
              ? LinearGradient(
                  colors: [
                    roleColor.withValues(alpha: _hovered ? 0.06 : 0.03),
                    Colors.transparent,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: isHighRank
              ? null
              : (_hovered
                  ? Colors.white.withValues(alpha: 0.02)
                  : Colors.transparent),
          border: widget.isLast
              ? null
              : Border(
                  bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.5)),
                ),
        ),
        child: Row(
          children: [
            // Role badge
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                    color: roleColor.withValues(alpha: 0.25)),
                boxShadow: isHighRank
                    ? [
                        BoxShadow(
                          color: roleColor.withValues(alpha: 0.2),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              child: Icon(_roleIcon(m.role), size: 16, color: roleColor),
            ),
            const SizedBox(width: 12),

            // Name + role label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.gamerTag,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: m.role == ClanRole.leader
                          ? _gold
                          : AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    _roleLabel(m.role),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: roleColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),

            // Trophies
            if (!widget.isMobile) ...[
              Icon(Icons.emoji_events_rounded,
                  size: 14, color: _gold.withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              SizedBox(
                width: 50,
                child: Text(
                  _formatNumber(m.trophies),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],

            // Donations
            Icon(Icons.volunteer_activism_rounded,
                size: 14,
                color: AppTheme.solanaGreen.withValues(alpha: 0.6)),
            const SizedBox(width: 4),
            Text(
              '${m.donations}',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// War Log
// ═══════════════════════════════════════════════════════════════════════════════

class _WarLog extends StatelessWidget {
  final List<ClanWarResult> warLog;
  const _WarLog({required this.warLog});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: List.generate(warLog.length, (i) {
          final w = warLog[i];
          return _WarLogRow(war: w, isLast: i == warLog.length - 1);
        }),
      ),
    );
  }
}

class _WarLogRow extends StatelessWidget {
  final ClanWarResult war;
  final bool isLast;
  const _WarLogRow({required this.war, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final resultColor = war.won ? AppTheme.success : AppTheme.error;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            resultColor.withValues(alpha: 0.04),
            Colors.transparent,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: const [0, 0.4],
        ),
        border: isLast
            ? null
            : Border(
                bottom:
                    BorderSide(color: AppTheme.border.withValues(alpha: 0.5)),
              ),
      ),
      child: IntrinsicHeight(
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Colored side accent strip
          Container(
            width: 3,
            decoration: BoxDecoration(
              color: resultColor,
              borderRadius: isLast
                  ? const BorderRadius.only(bottomLeft: Radius.circular(14))
                  : null,
              boxShadow: [
                BoxShadow(
                  color: resultColor.withValues(alpha: 0.3),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
              child: Row(
                children: [
                  // Result icon
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: resultColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                          color: resultColor.withValues(alpha: 0.25)),
                      boxShadow: [
                        BoxShadow(
                          color: resultColor.withValues(alpha: 0.12),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      war.won
                          ? Icons.emoji_events_rounded
                          : Icons.close_rounded,
                      size: 16,
                      color: resultColor,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Opponent
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              war.won ? 'Victory' : 'Defeat',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: resultColor,
                              ),
                            ),
                            Text(
                              '  vs  ',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                            Text(
                              war.opponentName,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_daysAgo(war.date)}  ·  [${war.opponentTag}]',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Stars
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, size: 14, color: _gold),
                      const SizedBox(width: 2),
                      Text(
                        '${war.starsEarned}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _gold,
                        ),
                      ),
                      Text(
                        ' - ${war.starsOpponent}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// No Clan Banner
// ═══════════════════════════════════════════════════════════════════════════════

class _NoClanBanner extends StatelessWidget {
  final bool isMobile;
  const _NoClanBanner({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1520), Color(0xFF251840), Color(0xFF1A2035)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppTheme.solanaPurple.withValues(alpha: 0.15)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CustomPaint(painter: _DiagonalPatternPainter()),
            ),
          ),
          Positioned(
            top: -40,
            right: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.solanaPurple.withValues(alpha: 0.08),
                    AppTheme.solanaPurple.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isMobile ? 24 : 32),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ClanShield(level: 0, size: 56),
                      const SizedBox(height: 16),
                      _noClanText(context),
                    ],
                  )
                : Row(
                    children: [
                      _ClanShield(level: 0, size: 64),
                      const SizedBox(width: 24),
                      Expanded(child: _noClanText(context)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _noClanText(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Join a Clan',
          style: GoogleFonts.inter(
            fontSize: isMobile ? 20 : 24,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Team up with traders, battle in clan wars, and earn trophies together.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.45),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _GoldButton(
              label: 'Create Clan',
              icon: Icons.add_rounded,
              onTap: () => showCreateClanModal(context),
            ),
            const SizedBox(width: 10),
            Text(
              'or browse below',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Connect Wallet Banner
// ═══════════════════════════════════════════════════════════════════════════════

class _ConnectWalletBanner extends StatelessWidget {
  final bool isMobile;
  const _ConnectWalletBanner({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1520), Color(0xFF1E1830), Color(0xFF1A2035)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CustomPaint(painter: _DiagonalPatternPainter()),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 24 : 32,
              vertical: isMobile ? 36 : 44,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.solanaPurple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: AppTheme.solanaPurple.withValues(alpha: 0.12)),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 32,
                    color: AppTheme.solanaPurple.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Connect Wallet to Join Clans',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Link your Solana wallet to create or join a clan',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => showConnectWalletModal(context),
                  icon: const Icon(
                      Icons.account_balance_wallet_rounded, size: 18),
                  label: const Text('Connect Wallet'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Gold Button — Clash-style CTA
// ═══════════════════════════════════════════════════════════════════════════════

class _GoldButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _GoldButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_GoldButton> createState() => _GoldButtonState();
}

class _GoldButtonState extends State<_GoldButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _hovered
                  ? [_gold, _goldDark]
                  : [_goldDim.withValues(alpha: 0.3), _gold.withValues(alpha: 0.2)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _gold.withValues(alpha: _hovered ? 0.8 : 0.3),
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: _gold.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon,
                  size: 16, color: _hovered ? const Color(0xFF1A1520) : _gold),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _hovered ? const Color(0xFF1A1520) : _gold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Search Bar
// ═══════════════════════════════════════════════════════════════════════════════

class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search clans...',
        hintStyle: GoogleFonts.inter(fontSize: 14, color: AppTheme.textTertiary),
        prefixIcon: const Icon(Icons.search_rounded,
            color: AppTheme.textTertiary, size: 20),
        filled: true,
        fillColor: AppTheme.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: AppTheme.solanaPurple.withValues(alpha: 0.5), width: 1.5),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Clan Card — clean browse list item
// ═══════════════════════════════════════════════════════════════════════════════

class _ClanCard extends ConsumerStatefulWidget {
  final int rank;
  final Clan clan;
  final bool canJoin;
  final bool isMobile;

  const _ClanCard({
    required this.rank,
    required this.clan,
    required this.canJoin,
    required this.isMobile,
  });

  @override
  ConsumerState<_ClanCard> createState() => _ClanCardState();
}

class _ClanCardState extends ConsumerState<_ClanCard> {
  bool _hovered = false;
  bool _btnHovered = false;

  static const _rankColors = [
    Color(0xFFFFD700), // gold
    Color(0xFFA8B4C0), // silver
    Color(0xFFCD7F32), // bronze
  ];

  @override
  Widget build(BuildContext context) {
    final clan = widget.clan;
    final rank = widget.rank;
    final isTop3 = rank <= 3;
    final cardHover = _hovered && !_btnHovered;
    final isFull = clan.memberCount >= clan.maxMembers;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 4),
        padding: EdgeInsets.symmetric(
          horizontal: widget.isMobile ? 12 : 16,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: cardHover ? AppTheme.surfaceAlt : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cardHover
                ? Colors.white.withValues(alpha: 0.08)
                : AppTheme.border,
          ),
        ),
        child: Row(
          children: [
            // ── Rank ────────────────────────────────────────────
            SizedBox(
              width: 28,
              child: isTop3
                  ? Center(
                      child: Text(
                        '$rank',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: _rankColors[rank - 1],
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        '$rank',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),

            // ── Clan info ───────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name row
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          clan.name,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: cardHover
                                ? Colors.white
                                : AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        clan.tag,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                      if (clan.isWarActive) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _warRed,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _warRed.withValues(alpha: 0.4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Stats row
                  Row(
                    children: [
                      _MiniStat(
                        icon: Icons.emoji_events_rounded,
                        iconColor: _gold.withValues(alpha: 0.5),
                        text: _formatNumber(clan.trophies),
                      ),
                      const SizedBox(width: 12),
                      _MiniStat(
                        icon: Icons.people_rounded,
                        iconColor: AppTheme.textTertiary,
                        text: '${clan.memberCount}/${clan.maxMembers}',
                        textColor: isFull ? AppTheme.error : null,
                      ),
                      if (!widget.isMobile) ...[
                        const SizedBox(width: 12),
                        _MiniStat(
                          icon: Icons.trending_up_rounded,
                          iconColor: _winRateColor(clan.winRate)
                              .withValues(alpha: 0.6),
                          text: '${clan.winRate}%',
                          textColor: _winRateColor(clan.winRate),
                        ),
                        if (clan.requiredTrophies > 0) ...[
                          const SizedBox(width: 12),
                          _MiniStat(
                            icon: Icons.lock_outline_rounded,
                            iconColor: AppTheme.textTertiary,
                            text: _formatNumber(clan.requiredTrophies),
                          ),
                        ],
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // ── Level pill ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Text(
                'Lv${clan.level}',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textTertiary,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // ── Action ──────────────────────────────────────────
            if (isFull)
              Text(
                'Full',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textTertiary.withValues(alpha: 0.5),
                ),
              )
            else if (widget.canJoin)
              _JoinButton(
                onTap: () =>
                    ref.read(clanProvider.notifier).joinClan(clan.id),
                onHoverChanged: (h) =>
                    setState(() => _btnHovered = h),
              ),
          ],
        ),
      ),
    );
  }

  Color _winRateColor(int rate) {
    if (rate >= 60) return AppTheme.success;
    if (rate >= 50) return AppTheme.warning;
    return AppTheme.error;
  }
}

// ── Mini Stat — icon + text pair used in clan cards ──────────────────────────

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  final Color? textColor;

  const _MiniStat({
    required this.icon,
    required this.iconColor,
    required this.text,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: iconColor),
        const SizedBox(width: 3),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: textColor ?? AppTheme.textTertiary,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Empty State
// ═══════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded,
              size: 32, color: AppTheme.textTertiary),
          const SizedBox(height: 10),
          Text(
            'No clans found',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Leave Button
// ═══════════════════════════════════════════════════════════════════════════════

class _LeaveButton extends StatefulWidget {
  final VoidCallback onTap;
  const _LeaveButton({required this.onTap});

  @override
  State<_LeaveButton> createState() => _LeaveButtonState();
}

class _LeaveButtonState extends State<_LeaveButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _hovered
                ? AppTheme.error.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered
                  ? AppTheme.error.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Text(
            'Leave',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _hovered
                  ? AppTheme.error
                  : Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Join Button
// ═══════════════════════════════════════════════════════════════════════════════

class _JoinButton extends StatefulWidget {
  final VoidCallback onTap;
  final ValueChanged<bool>? onHoverChanged;
  const _JoinButton({required this.onTap, this.onHoverChanged});

  @override
  State<_JoinButton> createState() => _JoinButtonState();
}

class _JoinButtonState extends State<_JoinButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _hovered = true);
        widget.onHoverChanged?.call(true);
      },
      onExit: (_) {
        setState(() => _hovered = false);
        widget.onHoverChanged?.call(false);
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: _hovered
                ? AppTheme.solanaPurple
                : AppTheme.solanaPurple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Join',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _hovered
                  ? Colors.white
                  : AppTheme.solanaPurple,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Diagonal Pattern Painter — subtle background texture
// ═══════════════════════════════════════════════════════════════════════════════

class _DiagonalPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.012)
      ..strokeWidth = 1;

    const spacing = 24.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════════

String _formatNumber(int n) {
  if (n >= 1000) {
    return '${(n / 1000).toStringAsFixed(1)}k';
  }
  return '$n';
}

String _daysAgo(DateTime date) {
  final diff = DateTime.now().difference(date).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '${diff}d ago';
}
