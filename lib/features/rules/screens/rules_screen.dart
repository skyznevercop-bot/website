import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

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
              _RulesHero(isMobile: isMobile),
              const SizedBox(height: 40),

              // ── Match Rules ─────────────────────────────────────
              _SectionHeader(
                icon: Icons.sports_esports_rounded,
                color: AppTheme.solanaPurple,
                title: 'Match Rules',
              ),
              const SizedBox(height: 16),
              ..._matchRules.map((r) => _RuleCard(rule: r)),

              const SizedBox(height: 40),

              // ── Trading Rules ────────────────────────────────────
              _SectionHeader(
                icon: Icons.candlestick_chart_rounded,
                color: AppTheme.solanaGreen,
                title: 'Trading Rules',
              ),
              const SizedBox(height: 16),
              ..._tradingRules.map((r) => _RuleCard(rule: r)),

              const SizedBox(height: 40),

              // ── Fair Play ───────────────────────────────────────
              _SectionHeader(
                icon: Icons.shield_rounded,
                color: AppTheme.error,
                title: 'Fair Play & Anti-Cheat',
              ),
              const SizedBox(height: 16),
              ..._fairPlayRules.map((r) => _RuleCard(rule: r)),

              const SizedBox(height: 40),

              // ── Fees & Payouts ──────────────────────────────────
              _SectionHeader(
                icon: Icons.account_balance_wallet_rounded,
                color: AppTheme.warning,
                title: 'Fees & Payouts',
              ),
              const SizedBox(height: 16),
              const _FeesTable(),

              const SizedBox(height: 40),

              // ── FAQ ─────────────────────────────────────────────
              _SectionHeader(
                icon: Icons.quiz_rounded,
                color: AppTheme.info,
                title: 'Frequently Asked Questions',
              ),
              const SizedBox(height: 16),
              const _RulesFaq(),
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

class _Rule {
  final String title;
  final String body;
  const _Rule(this.title, this.body);
}

const _matchRules = [
  _Rule(
    '1v1 Format',
    'Every match is a head-to-head battle between two players. Both players start with an identical \$1,000,000 virtual portfolio and trade simultaneously.',
  ),
  _Rule(
    'Match Durations',
    'Choose from 5 minutes, 15 minutes, 1 hour, 4 hours, or 24 hours. The timer starts as soon as both players are connected.',
  ),
  _Rule(
    'Bet Amounts',
    'Both players wager the same amount in USDC. Available stakes: \$5, \$10, \$50, \$100, or \$1,000. The winner takes the combined pot minus platform fees.',
  ),
  _Rule(
    'Winning Condition',
    'The player with the higher portfolio P&L (unrealized + realized) at the end of the timer wins. If P&L is exactly tied, the pot is refunded to both players.',
  ),
  _Rule(
    'Disconnections',
    'If you disconnect, your open positions stay active. You can rejoin at any time. If you fail to reconnect, your final P&L is calculated from remaining positions at match end.',
  ),
];

const _tradingRules = [
  _Rule(
    'Available Assets',
    'Trade BTC/USD, ETH/USD, and SOL/USD. More pairs may be added in the future.',
  ),
  _Rule(
    'Leverage',
    'Maximum leverage is 100x on all assets (BTC, ETH, SOL). Leverage is applied per-position.',
  ),
  _Rule(
    'Position Limits',
    'You may hold multiple positions simultaneously across different assets. There is no limit on the number of trades you can make during a match.',
  ),
  _Rule(
    'Liquidation',
    'Positions are liquidated if your margin falls below the maintenance requirement. Liquidated positions are closed at the liquidation price.',
  ),
  _Rule(
    'Match End',
    'All open positions are automatically marked-to-market at the final price when the timer expires. You can also close positions manually before the match ends to lock in P&L.',
  ),
];

const _fairPlayRules = [
  _Rule(
    'No Collusion',
    'Coordinating with your opponent or any third party to manipulate match outcomes is strictly prohibited and will result in a permanent ban.',
  ),
  _Rule(
    'No Multi-Accounting',
    'Each player may only use one account. Creating multiple accounts to exploit matchmaking or referral rewards will result in all accounts being banned.',
  ),
  _Rule(
    'No Automated Trading',
    'Bots, scripts, macros, or any form of automated trading during matches is not allowed. All trades must be placed manually.',
  ),
  _Rule(
    'Dispute Resolution',
    'If you believe a match result was incorrect due to a technical issue, contact support within 24 hours. We review server-side logs to resolve disputes fairly.',
  ),
];

// ═══════════════════════════════════════════════════════════════════════════════
// Hero
// ═══════════════════════════════════════════════════════════════════════════════

class _RulesHero extends StatelessWidget {
  final bool isMobile;
  const _RulesHero({required this.isMobile});

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
                    const Icon(Icons.description_rounded,
                        color: Colors.white54, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Rules & FAQ',
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
                  'Rules of the Arena',
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
                  'Everything you need to know about how matches work, trading mechanics, and fair play policies.',
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
// Shared Section Header
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
// Rule Card
// ═══════════════════════════════════════════════════════════════════════════════

class _RuleCard extends StatelessWidget {
  final _Rule rule;
  const _RuleCard({required this.rule});

  @override
  Widget build(BuildContext context) {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rule.title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              rule.body,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Fees Table
// ═══════════════════════════════════════════════════════════════════════════════

class _FeesTable extends StatelessWidget {
  const _FeesTable();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          _feeRow('Platform Fee', '10% of the total pot', true),
          const Divider(height: 1, color: AppTheme.border),
          _feeRow('Winner Payout', '90% of the total pot', false),
          const Divider(height: 1, color: AppTheme.border),
          _feeRow('Draw / Tie', 'Full refund to both players', false),
          const Divider(height: 1, color: AppTheme.border),
          _feeRow('Deposits', 'Free (only Solana network fees apply)', false),
          const Divider(height: 1, color: AppTheme.border),
          _feeRow('Withdrawals', 'Free (only Solana network fees apply)', false),
        ],
      ),
    );
  }

  Widget _feeRow(String label, String value, bool isFirst) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Rules FAQ
// ═══════════════════════════════════════════════════════════════════════════════

class _RulesFaq extends StatefulWidget {
  const _RulesFaq();

  @override
  State<_RulesFaq> createState() => _RulesFaqState();
}

class _RulesFaqState extends State<_RulesFaq> {
  int? _expandedIndex;

  static const _faqs = [
    (
      q: 'Can I cancel a match after entering the queue?',
      a: 'Yes, you can leave the queue at any time before being matched. Once matched, the bet is locked and the match begins.',
    ),
    (
      q: 'What happens if the match timer runs out while I have no open positions?',
      a: 'Your P&L is calculated from your realized trades. If you never placed a trade, your P&L is \$0.',
    ),
    (
      q: 'Are prices the same for both players?',
      a: 'Yes. Both players see identical real-time price feeds throughout the match. Prices are sourced from major exchanges to ensure accuracy.',
    ),
    (
      q: 'Can I play on mobile?',
      a: 'SolFight is optimized for desktop browsers but works on mobile. The trading interface is best experienced on a larger screen.',
    ),
    (
      q: 'Is there a minimum balance to play?',
      a: 'You need enough USDC in your SolFight wallet to cover the bet amount. The minimum bet is \$5.',
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
                        ? AppTheme.info.withValues(alpha: 0.3)
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
