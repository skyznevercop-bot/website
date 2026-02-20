import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

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
              _AboutHero(isMobile: isMobile),
              const SizedBox(height: 40),

              // ── What is SolFight ────────────────────────────────
              _SectionHeader(
                icon: Icons.bolt_rounded,
                color: AppTheme.solanaPurple,
                title: 'What is SolFight?',
              ),
              const SizedBox(height: 16),
              _ContentCard(
                children: [
                  _paragraph(
                    'SolFight is a competitive 1v1 trading arena built on Solana. '
                    'Two players enter a match, each starting with \$1,000,000 in virtual funds, '
                    'and trade BTC, ETH, and SOL in real time. The player with the higher P&L '
                    'when the timer expires wins the combined USDC pot.',
                  ),
                  const SizedBox(height: 12),
                  _paragraph(
                    'Think of it as chess meets trading — pure skill, real stakes, no luck. '
                    'Whether you\'re a day-trader sharpening your edge or a newcomer learning the ropes, '
                    'SolFight gives you a fair arena to prove yourself.',
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // ── Why Solana ──────────────────────────────────────
              _SectionHeader(
                icon: Icons.speed_rounded,
                color: AppTheme.solanaGreen,
                title: 'Why Solana?',
              ),
              const SizedBox(height: 16),
              _ContentCard(
                children: [
                  _paragraph(
                    'Solana\'s sub-second finality and near-zero transaction fees make it the ideal chain '
                    'for a real-time competitive platform. Deposits, match settlements, and withdrawals happen '
                    'almost instantly — no waiting for confirmations, no gas anxiety.',
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // ── Core Values ─────────────────────────────────────
              _SectionHeader(
                icon: Icons.diamond_rounded,
                color: AppTheme.warning,
                title: 'Core Values',
              ),
              const SizedBox(height: 16),
              const _ValueCards(),

              const SizedBox(height: 40),

              // ── Roadmap Highlights ──────────────────────────────
              _SectionHeader(
                icon: Icons.map_rounded,
                color: AppTheme.info,
                title: 'Roadmap Highlights',
              ),
              const SizedBox(height: 16),
              const _RoadmapSection(),

              const SizedBox(height: 40),

              // ── Community ───────────────────────────────────────
              _SectionHeader(
                icon: Icons.people_rounded,
                color: AppTheme.solanaPurple,
                title: 'Join the Community',
              ),
              const SizedBox(height: 16),
              const _CommunityLinks(),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _paragraph(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        color: AppTheme.textSecondary,
        height: 1.7,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Hero
// ═══════════════════════════════════════════════════════════════════════════════

class _AboutHero extends StatelessWidget {
  final bool isMobile;
  const _AboutHero({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C1F2E), Color(0xFF2D1B69), Color(0xFF4A2198)],
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
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppTheme.solanaPurple.withValues(alpha: 0.15),
                  AppTheme.solanaPurple.withValues(alpha: 0),
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: -15,
            left: -15,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppTheme.solanaGreen.withValues(alpha: 0.08),
                  AppTheme.solanaGreen.withValues(alpha: 0),
                ]),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isMobile ? 24 : 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: Colors.white54, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'About',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white54,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'About SolFight',
                  style: GoogleFonts.inter(
                    fontSize: isMobile ? 28 : 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '1v1 Trading Battles on Solana. Skill-based, transparent, and built for competitors.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.5),
                    height: 1.5,
                  ),
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
  final IconData icon;
  final Color color;
  final String title;

  const _SectionHeader({
    required this.icon,
    required this.color,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
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
}

// ═══════════════════════════════════════════════════════════════════════════════
// Content Card
// ═══════════════════════════════════════════════════════════════════════════════

class _ContentCard extends StatelessWidget {
  final List<Widget> children;
  const _ContentCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Value Cards
// ═══════════════════════════════════════════════════════════════════════════════

class _ValueCards extends StatelessWidget {
  const _ValueCards();

  static const _values = [
    (
      icon: Icons.balance_rounded,
      color: AppTheme.solanaPurple,
      title: 'Fair Competition',
      desc: 'Identical starting conditions, real-time prices, no pay-to-win mechanics. Every match is decided by skill alone.',
    ),
    (
      icon: Icons.visibility_rounded,
      color: AppTheme.solanaGreen,
      title: 'Transparency',
      desc: 'Bets and settlements happen on-chain via Solana smart contracts. Every transaction is verifiable.',
    ),
    (
      icon: Icons.security_rounded,
      color: AppTheme.warning,
      title: 'Security First',
      desc: 'Non-custodial architecture — your funds stay in your wallet until a match begins. Smart contract escrow for all bets.',
    ),
    (
      icon: Icons.groups_rounded,
      color: AppTheme.info,
      title: 'Community Driven',
      desc: 'Built with feedback from traders. Feature requests, bug reports, and suggestions directly shape the roadmap.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _values.map((v) {
        final cardWidth = Responsive.value<double>(context,
            mobile: MediaQuery.sizeOf(context).width - 32,
            tablet: (MediaQuery.sizeOf(context).width - 80) / 2,
            desktop: (MediaQuery.sizeOf(context).width - 144) / 2);

        return Container(
          width: cardWidth.clamp(0, 380),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: v.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(v.icon, color: v.color, size: 22),
              ),
              const SizedBox(height: 14),
              Text(
                v.title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                v.desc,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Roadmap
// ═══════════════════════════════════════════════════════════════════════════════

class _RoadmapSection extends StatelessWidget {
  const _RoadmapSection();

  static const _milestones = [
    (label: 'Live', title: 'Core Arena', desc: '1v1 matches, USDC wagering, BTC/ETH/SOL trading', done: true),
    (label: 'Live', title: 'Clans & Leaderboards', desc: 'Form teams, compete for seasonal rankings', done: true),
    (label: 'Live', title: 'Learn Hub', desc: 'Structured lessons, glossary, and quick tips', done: true),
    (label: 'Next', title: 'Tournament Mode', desc: 'Bracket-style tournaments with prize pools', done: false),
    (label: 'Next', title: 'More Assets', desc: 'Additional trading pairs and asset classes', done: false),
    (label: 'Future', title: 'Mobile App', desc: 'Native iOS and Android experience', done: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _milestones.map((m) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: m.done
                        ? AppTheme.success.withValues(alpha: 0.1)
                        : AppTheme.solanaPurple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    m.label,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: m.done ? AppTheme.success : AppTheme.solanaPurple,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m.desc,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (m.done)
                  const Icon(Icons.check_circle_rounded,
                      size: 18, color: AppTheme.success),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Community Links
// ═══════════════════════════════════════════════════════════════════════════════

class _CommunityLinks extends StatelessWidget {
  const _CommunityLinks();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _SocialButton(
          icon: Icons.discord,
          label: 'Discord',
          color: const Color(0xFF5865F2),
          onTap: () => launchUrl(Uri.parse('https://discord.gg/f9EvNCWmr6')),
        ),
        _SocialButton(
          icon: Icons.alternate_email_rounded,
          label: '@sol_fight',
          color: AppTheme.textPrimary,
          onTap: () => launchUrl(Uri.parse('https://x.com/sol_fight')),
        ),
      ],
    );
  }
}

class _SocialButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<_SocialButton> {
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
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: _hovered ? AppTheme.surfaceAlt : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.3)
                  : AppTheme.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: widget.color, size: 20),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.open_in_new_rounded,
                  size: 14, color: AppTheme.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
