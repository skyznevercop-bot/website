import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

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
              _HelpHero(isMobile: isMobile),
              const SizedBox(height: 40),
              _SectionHeader(
                icon: Icons.bolt_rounded,
                color: AppTheme.warning,
                title: 'Quick Start',
              ),
              const SizedBox(height: 16),
              const _QuickStartSteps(),
              const SizedBox(height: 40),
              _SectionHeader(
                icon: Icons.question_answer_rounded,
                color: AppTheme.info,
                title: 'Common Questions',
              ),
              const SizedBox(height: 16),
              const _FaqSection(),
              const SizedBox(height: 40),
              _SectionHeader(
                icon: Icons.headset_mic_rounded,
                color: AppTheme.solanaPurple,
                title: 'Contact Support',
              ),
              const SizedBox(height: 16),
              const _ContactCards(),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Hero
// ═══════════════════════════════════════════════════════════════════════════════

class _HelpHero extends StatelessWidget {
  final bool isMobile;
  const _HelpHero({required this.isMobile});

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
          Padding(
            padding: EdgeInsets.all(isMobile ? 24 : 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.help_outline_rounded,
                        color: Colors.white54, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Help Center',
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
                  'How Can We Help?',
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
                  'Find answers to common questions, learn how SolFight works, or reach out to our team.',
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
// Quick Start Steps
// ═══════════════════════════════════════════════════════════════════════════════

class _QuickStartSteps extends StatelessWidget {
  const _QuickStartSteps();

  static const _steps = [
    (
      num: '1',
      title: 'Connect Your Wallet',
      desc:
          'Click "Connect Wallet" in the top-right corner. We support Phantom, Solflare, and other major Solana wallets.',
    ),
    (
      num: '2',
      title: 'Fund Your Account',
      desc:
          'Deposit USDC to your SolFight wallet. This is the currency used for all bets and payouts.',
    ),
    (
      num: '3',
      title: 'Join a Match',
      desc:
          'Head to the Play tab, pick a duration and bet amount, then hit "Find Match" to enter the queue.',
    ),
    (
      num: '4',
      title: 'Trade & Win',
      desc:
          'You and your opponent each get \$1M in virtual funds. Trade BTC, ETH, and SOL — the higher P&L at the end wins the pot.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _steps.map((step) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: AppTheme.purpleGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      step.num,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        step.desc,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FAQ Section
// ═══════════════════════════════════════════════════════════════════════════════

class _FaqSection extends StatefulWidget {
  const _FaqSection();

  @override
  State<_FaqSection> createState() => _FaqSectionState();
}

class _FaqSectionState extends State<_FaqSection> {
  int? _expandedIndex;

  static const _faqs = [
    (
      q: 'Is real money at risk during a match?',
      a: 'No. Each match uses \$1M in virtual (demo) funds. Only your USDC bet is at stake — the winner takes the combined pot minus a small platform fee.',
    ),
    (
      q: 'Which wallets are supported?',
      a: 'SolFight supports all major Solana wallets including Phantom, Solflare, Backpack, and any wallet that implements the Solana Wallet Standard.',
    ),
    (
      q: 'How are winners determined?',
      a: 'At the end of the match timer, the player with the higher portfolio P&L (profit & loss) wins. If both players have identical P&L, the pot is refunded.',
    ),
    (
      q: 'What assets can I trade?',
      a: 'Currently you can trade BTC, ETH, and SOL with up to 100x leverage. More assets will be added over time.',
    ),
    (
      q: 'What happens if I disconnect mid-match?',
      a: 'Your open positions remain active. You can reconnect at any time and continue trading. If you don\'t reconnect before the match ends, your final P&L is calculated from your open positions.',
    ),
    (
      q: 'How do withdrawals work?',
      a: 'Winnings are credited to your SolFight wallet instantly after a match. You can withdraw USDC back to your Solana wallet at any time from the Portfolio tab.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(_faqs.length, (i) {
        final faq = _faqs[i];
        final expanded = _expandedIndex == i;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => setState(() => _expandedIndex = expanded ? null : i),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: expanded
                        ? AppTheme.solanaPurple.withValues(alpha: 0.3)
                        : AppTheme.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            faq.q,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        Icon(
                          expanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: AppTheme.textTertiary,
                          size: 20,
                        ),
                      ],
                    ),
                    if (expanded) ...[
                      const SizedBox(height: 10),
                      Text(
                        faq.a,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Contact Cards
// ═══════════════════════════════════════════════════════════════════════════════

class _ContactCards extends StatelessWidget {
  const _ContactCards();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _ContactCard(
          icon: Icons.discord,
          label: 'Discord',
          description: 'Join our community for live support and chat.',
          color: const Color(0xFF5865F2),
          onTap: () => launchUrl(Uri.parse('https://discord.gg/f9EvNCWmr6')),
        ),
        _ContactCard(
          icon: Icons.alternate_email_rounded,
          label: 'X (Twitter)',
          description: 'Follow @solfight_io for updates and announcements.',
          color: AppTheme.textPrimary,
          onTap: () =>
              launchUrl(Uri.parse('https://x.com/solfight_io')),
        ),
        _ContactCard(
          icon: Icons.email_outlined,
          label: 'Email',
          description: 'Reach us at support@solfight.io for account issues.',
          color: AppTheme.solanaPurple,
          onTap: () => launchUrl(Uri.parse('mailto:support@solfight.io')),
        ),
      ],
    );
  }
}

class _ContactCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _ContactCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends State<_ContactCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cardWidth = Responsive.value<double>(context,
        mobile: MediaQuery.sizeOf(context).width - 32,
        tablet: (MediaQuery.sizeOf(context).width - 80) / 2,
        desktop: (MediaQuery.sizeOf(context).width - 144) / 3);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: cardWidth.clamp(0, 350),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _hovered ? AppTheme.surfaceAlt : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.3)
                  : AppTheme.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, color: widget.color, size: 22),
              ),
              const SizedBox(height: 14),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.description,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
