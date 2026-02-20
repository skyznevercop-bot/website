import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

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
              _TermsHero(isMobile: isMobile),
              const SizedBox(height: 12),
              Text(
                'Last updated: February 20, 2026',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                ),
              ),
              const SizedBox(height: 32),
              ..._sections.map((s) => _TermsSection(section: s)),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Data
// ═══════════════════════════════════════════════════════════════════════════════

class _Section {
  final String title;
  final String body;
  const _Section(this.title, this.body);
}

const _sections = [
  _Section(
    '1. Acceptance of Terms',
    'By accessing or using the SolFight platform (the "Service"), you agree to be bound by these Terms & Conditions ("Terms"). If you do not agree, do not use the Service. SolFight reserves the right to modify these Terms at any time. Continued use after changes constitutes acceptance.',
  ),
  _Section(
    '2. Eligibility',
    'You must be at least 18 years old to use SolFight. By using the Service, you represent and warrant that you meet this age requirement and that your use of SolFight does not violate any applicable laws or regulations in your jurisdiction.',
  ),
  _Section(
    '3. Account & Wallet',
    'SolFight uses wallet-based authentication. You are solely responsible for maintaining the security of your wallet and private keys. SolFight does not store or have access to your private keys. Any actions performed using your connected wallet are your responsibility.',
  ),
  _Section(
    '4. The Service',
    'SolFight provides a platform for competitive 1v1 trading matches. Players wager USDC and trade virtual portfolios in real time. Key points:\n\n'
    '• Matches use simulated portfolios (\$1M virtual funds); only the USDC wager is real.\n'
    '• Match results are determined by portfolio P&L at timer expiry.\n'
    '• SolFight charges a platform fee (currently 10%) deducted from the winning pot.\n'
    '• Prices are sourced from third-party data providers and may differ from other exchanges.',
  ),
  _Section(
    '5. Deposits & Withdrawals',
    'All deposits and withdrawals are processed on the Solana blockchain in USDC. SolFight does not charge deposit or withdrawal fees beyond Solana network transaction fees. Processing times depend on Solana network conditions.',
  ),
  _Section(
    '6. Match Rules & Fair Play',
    'All users must abide by SolFight\'s match rules and fair play policies as outlined on the Rules & FAQ page. Prohibited activities include but are not limited to:\n\n'
    '• Collusion with opponents or third parties.\n'
    '• Use of bots, scripts, or automated trading tools.\n'
    '• Creating multiple accounts (multi-accounting).\n'
    '• Exploiting bugs or vulnerabilities.\n\n'
    'Violations may result in account suspension, forfeiture of funds, and permanent bans at SolFight\'s sole discretion.',
  ),
  _Section(
    '7. Intellectual Property',
    'All content, branding, design, code, and materials on the SolFight platform are the property of SolFight and are protected by intellectual property laws. You may not copy, modify, distribute, or create derivative works without explicit written permission.',
  ),
  _Section(
    '8. Disclaimer of Warranties',
    'The Service is provided "as is" and "as available" without warranties of any kind, express or implied. SolFight does not warrant that:\n\n'
    '• The Service will be uninterrupted, timely, secure, or error-free.\n'
    '• Price feeds will be perfectly accurate or identical to other platforms.\n'
    '• Results or outcomes will meet your expectations.\n\n'
    'You use the Service at your own risk.',
  ),
  _Section(
    '9. Limitation of Liability',
    'To the maximum extent permitted by law, SolFight and its team shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising from your use of the Service, including but not limited to loss of funds, data, or profits, even if advised of the possibility of such damages.\n\n'
    'SolFight\'s total liability for any claim shall not exceed the amount you deposited into the platform in the 30 days preceding the claim.',
  ),
  _Section(
    '10. Assumption of Risk',
    'By using SolFight, you acknowledge and accept the following risks:\n\n'
    '• Cryptocurrency and blockchain technology carry inherent risks including volatility and potential loss of funds.\n'
    '• Smart contracts, while audited, may contain undiscovered vulnerabilities.\n'
    '• Regulatory changes may affect the availability of the Service in your jurisdiction.\n'
    '• SolFight is a skill-based competition; losing bets is an expected outcome.',
  ),
  _Section(
    '11. Indemnification',
    'You agree to indemnify and hold harmless SolFight, its affiliates, and team members from any claims, losses, or expenses (including legal fees) arising from your use of the Service, violation of these Terms, or infringement of any third-party rights.',
  ),
  _Section(
    '12. Termination',
    'SolFight may suspend or terminate your access to the Service at any time, with or without cause, at its sole discretion. Upon termination, any pending withdrawable balance will remain available for withdrawal for 30 days, after which unclaimed funds may be forfeited.',
  ),
  _Section(
    '13. Governing Law',
    'These Terms shall be governed by and construed in accordance with applicable laws, without regard to conflict of law principles. Any disputes arising from these Terms shall be resolved through binding arbitration.',
  ),
  _Section(
    '14. Severability',
    'If any provision of these Terms is found to be unenforceable or invalid, that provision shall be limited or eliminated to the minimum extent necessary, and the remaining provisions shall remain in full force and effect.',
  ),
  _Section(
    '15. Contact',
    'For questions about these Terms & Conditions, contact us:\n\n'
    '• Email: support@solfight.io\n'
    '• Discord: https://discord.gg/f9EvNCWmr6\n'
    '• X (Twitter): @sol_fight',
  ),
];

// ═══════════════════════════════════════════════════════════════════════════════
// Hero
// ═══════════════════════════════════════════════════════════════════════════════

class _TermsHero extends StatelessWidget {
  final bool isMobile;
  const _TermsHero({required this.isMobile});

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
                    const Icon(Icons.gavel_rounded,
                        color: Colors.white54, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Legal',
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
                  'Terms & Conditions',
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
                  'The rules that govern your use of the SolFight platform.',
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
// Terms Section
// ═══════════════════════════════════════════════════════════════════════════════

class _TermsSection extends StatelessWidget {
  final _Section section;
  const _TermsSection({required this.section});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            section.body,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}
