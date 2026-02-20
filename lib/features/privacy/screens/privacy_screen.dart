import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

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
              _PrivacyHero(isMobile: isMobile),
              const SizedBox(height: 12),
              Text(
                'Last updated: February 20, 2026',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                ),
              ),
              const SizedBox(height: 32),
              ..._sections.map((s) => _PolicySection(section: s)),
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
    '1. Introduction',
    'SolFight ("we", "us", "our") operates the SolFight platform (the "Service"), a competitive 1v1 trading arena built on the Solana blockchain. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our Service. By using SolFight, you consent to the practices described in this policy.',
  ),
  _Section(
    '2. Information We Collect',
    'Wallet Address: When you connect your Solana wallet, we collect your public wallet address. This is required to facilitate deposits, match settlements, and withdrawals.\n\n'
    'On-Chain Transaction Data: All match bets, settlements, and transfers are recorded on the Solana blockchain and are publicly visible.\n\n'
    'Usage Data: We collect anonymized usage analytics including pages visited, match history, features used, device type, browser type, and approximate geographic region.\n\n'
    'Communications: If you contact us via email, Discord, or the feedback form, we retain the content of those communications to provide support.',
  ),
  _Section(
    '3. Information We Do NOT Collect',
    'We do not collect your real name, email address (unless you voluntarily provide it), phone number, government-issued ID, or any other personally identifiable information (PII). SolFight is designed to operate with wallet-based authentication only.',
  ),
  _Section(
    '4. How We Use Your Information',
    'We use the information we collect to:\n\n'
    '• Operate and maintain the Service, including matchmaking and settlements.\n'
    '• Detect and prevent fraud, collusion, multi-accounting, and other abuse.\n'
    '• Improve the platform based on aggregate usage patterns.\n'
    '• Communicate with you regarding support requests or service updates.\n'
    '• Comply with legal obligations where applicable.',
  ),
  _Section(
    '5. Data Sharing & Disclosure',
    'We do not sell, rent, or share your personal information with third parties for marketing purposes. We may share data in the following circumstances:\n\n'
    '• Service Providers: Trusted third parties that help us operate the platform (e.g., analytics, hosting) under strict confidentiality agreements.\n'
    '• Legal Requirements: When required by law, regulation, or legal process.\n'
    '• Safety: To protect the rights, safety, or property of SolFight, our users, or the public.',
  ),
  _Section(
    '6. Blockchain Data',
    'Transactions on the Solana blockchain are inherently public and immutable. Once recorded, on-chain data cannot be modified or deleted by SolFight or any party. Your wallet address and transaction history on-chain are visible to anyone.',
  ),
  _Section(
    '7. Cookies & Tracking',
    'We use essential cookies to maintain session state and remember your preferences (e.g., wallet connection). We use anonymized analytics to understand aggregate usage patterns. We do not use advertising cookies or trackers.',
  ),
  _Section(
    '8. Data Retention',
    'We retain usage analytics and match history for as long as the Service is active. If you wish to delete your off-chain data, contact us at support@solfight.io. On-chain data cannot be deleted due to the nature of blockchain technology.',
  ),
  _Section(
    '9. Security',
    'We implement industry-standard security measures including encrypted connections (HTTPS/TLS), secure smart contract architecture, and regular security audits. However, no system is 100% secure. You are responsible for safeguarding your wallet\'s private keys.',
  ),
  _Section(
    '10. Children\'s Privacy',
    'SolFight is not intended for anyone under the age of 18. We do not knowingly collect information from minors. If we learn that we have collected data from a minor, we will take steps to delete it promptly.',
  ),
  _Section(
    '11. Changes to This Policy',
    'We may update this Privacy Policy from time to time. Changes will be posted on this page with an updated "Last updated" date. Continued use of the Service after changes constitutes acceptance of the revised policy.',
  ),
  _Section(
    '12. Contact Us',
    'If you have questions about this Privacy Policy, contact us:\n\n'
    '• Email: support@solfight.io\n'
    '• Discord: https://discord.gg/f9EvNCWmr6\n'
    '• X (Twitter): @sol_fight',
  ),
];

// ═══════════════════════════════════════════════════════════════════════════════
// Hero
// ═══════════════════════════════════════════════════════════════════════════════

class _PrivacyHero extends StatelessWidget {
  final bool isMobile;
  const _PrivacyHero({required this.isMobile});

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
                    const Icon(Icons.privacy_tip_outlined,
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
                  'Privacy Policy',
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
                  'How we handle your data — transparently and responsibly.',
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
// Policy Section
// ═══════════════════════════════════════════════════════════════════════════════

class _PolicySection extends StatelessWidget {
  final _Section section;
  const _PolicySection({required this.section});

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
