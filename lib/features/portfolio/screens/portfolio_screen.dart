import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../features/wallet/providers/wallet_provider.dart';
import '../../../features/wallet/widgets/connect_wallet_modal.dart';
import '../models/transaction_models.dart';
import '../providers/portfolio_provider.dart';

/// Portfolio screen — wallet balance, open positions, match history, PnL chart.
class PortfolioScreen extends ConsumerWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    final portfolio = ref.watch(portfolioProvider);
    final isMobile = Responsive.isMobile(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),

          if (!wallet.isConnected) ...[
            // ── Header (always visible) ───────────────────────────────
            Padding(
              padding: Responsive.horizontalPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Portfolio',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track your balance, positions, and match history.',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Not connected state
            Padding(
              padding: Responsive.horizontalPadding(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 48),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 48,
                      color: AppTheme.textTertiary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Connect your wallet to view portfolio',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => showConnectWalletModal(context),
                      icon: const Icon(Icons.account_balance_wallet_rounded,
                          size: 18),
                      label: const Text('Connect Wallet'),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // ── Hero Portfolio Card ───────────────────────────────────
            Padding(
              padding: Responsive.horizontalPadding(context),
              child: _PortfolioHero(
                balance: wallet.usdcBalance ?? 0,
                isMobile: isMobile,
              ),
            ),
            const SizedBox(height: 32),

            // Active matches
            Padding(
              padding: Responsive.horizontalPadding(context),
              child: Text(
                'Active Matches',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: Responsive.horizontalPadding(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.border),
                ),
                child: _ActiveMatchRow(
                  opponent: 'CryptoKing',
                  timeframe: '1h',
                  yourPnl: '+2.4%',
                  oppPnl: '+1.1%',
                  timeLeft: '23m left',
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Match history
            Padding(
              padding: Responsive.horizontalPadding(context),
              child: Text(
                'Match History',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: Responsive.horizontalPadding(context),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: const [
                    _HistoryRow(
                        opponent: 'SolWhale',
                        timeframe: '15m',
                        result: 'WIN',
                        pnl: '+\$10.00'),
                    Divider(height: 1),
                    _HistoryRow(
                        opponent: 'MoonShot99',
                        timeframe: '4h',
                        result: 'WIN',
                        pnl: '+\$25.00'),
                    Divider(height: 1),
                    _HistoryRow(
                        opponent: 'BearSlayer',
                        timeframe: '1h',
                        result: 'LOSS',
                        pnl: '-\$25.00'),
                    Divider(height: 1),
                    _HistoryRow(
                        opponent: 'DeFiNinja',
                        timeframe: '30m',
                        result: 'WIN',
                        pnl: '+\$10.00'),
                    Divider(height: 1),
                    _HistoryRow(
                        opponent: 'TokenMaster',
                        timeframe: '15m',
                        result: 'WIN',
                        pnl: '+\$10.00'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Transaction history
            Padding(
              padding: Responsive.horizontalPadding(context),
              child: Text(
                'Transaction History',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: Responsive.horizontalPadding(context),
              child: portfolio.transactions.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusLg),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 36,
                            color: AppTheme.textTertiary,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No transactions yet',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusLg),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0;
                              i < portfolio.transactions.length;
                              i++) ...[
                            if (i > 0) const Divider(height: 1),
                            _TransactionRow(
                                tx: portfolio.transactions[i]),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Portfolio Hero Card
// ═══════════════════════════════════════════════════════════════════════════════

class _PortfolioHero extends StatelessWidget {
  final double balance;
  final bool isMobile;

  const _PortfolioHero({
    required this.balance,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C1F2E), Color(0xFF2D1B69), Color(0xFF3A1D8E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppTheme.solanaPurple.withValues(alpha: 0.15),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative glow orbs
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.solanaPurple.withValues(alpha: 0.2),
                    AppTheme.solanaPurple.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.solanaGreen.withValues(alpha: 0.1),
                    AppTheme.solanaGreen.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),

          // Content
          Padding(
            padding: EdgeInsets.all(isMobile ? 24 : 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Row(
                  children: [
                    Text(
                      'Portfolio',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.6),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.solanaGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppTheme.solanaGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Devnet',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.solanaGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Big balance
                Text(
                  '\$${balance.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: isMobile ? 36 : 48,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'USDC Balance',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),

                SizedBox(height: isMobile ? 24 : 28),

                // Stats row
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: isMobile
                      ? Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                    child: _HeroStat(
                                        label: 'In Play',
                                        value: '\$25.00',
                                        color: AppTheme.solanaPurpleLight)),
                                _statDivider(),
                                Expanded(
                                    child: _HeroStat(
                                        label: 'Total PnL',
                                        value: '+\$420.50',
                                        color: AppTheme.success)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Divider(
                                height: 1,
                                color:
                                    Colors.white.withValues(alpha: 0.08)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                    child: _HeroStat(
                                        label: 'Record',
                                        value: '4W - 1L',
                                        color: AppTheme.solanaGreen)),
                                _statDivider(),
                                Expanded(
                                    child: _HeroStat(
                                        label: 'Win Rate',
                                        value: '80%',
                                        color: AppTheme.warning)),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                                child: _HeroStat(
                                    label: 'In Play',
                                    value: '\$25.00',
                                    color: AppTheme.solanaPurpleLight)),
                            _statDivider(),
                            Expanded(
                                child: _HeroStat(
                                    label: 'Total PnL',
                                    value: '+\$420.50',
                                    color: AppTheme.success)),
                            _statDivider(),
                            Expanded(
                                child: _HeroStat(
                                    label: 'Record',
                                    value: '4W - 1L',
                                    color: AppTheme.solanaGreen)),
                            _statDivider(),
                            Expanded(
                                child: _HeroStat(
                                    label: 'Win Rate',
                                    value: '80%',
                                    color: AppTheme.warning)),
                          ],
                        ),
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HeroStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Active Match Row
// ═══════════════════════════════════════════════════════════════════════════════

class _ActiveMatchRow extends StatelessWidget {
  final String opponent;
  final String timeframe;
  final String yourPnl;
  final String oppPnl;
  final String timeLeft;

  const _ActiveMatchRow({
    required this.opponent,
    required this.timeframe,
    required this.yourPnl,
    required this.oppPnl,
    required this.timeLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // You
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                yourPnl,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
        ),

        // VS badge
        Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.solanaPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'VS  $timeframe',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.solanaPurple,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                timeLeft,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.warning,
                ),
              ),
            ),
          ],
        ),

        // Opponent
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                opponent,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                oppPnl,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.error,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// History Row
// ═══════════════════════════════════════════════════════════════════════════════

class _HistoryRow extends StatelessWidget {
  final String opponent;
  final String timeframe;
  final String result;
  final String pnl;

  const _HistoryRow({
    required this.opponent,
    required this.timeframe,
    required this.result,
    required this.pnl,
  });

  @override
  Widget build(BuildContext context) {
    final isWin = result == 'WIN';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // Result badge
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: (isWin ? AppTheme.success : AppTheme.error)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                result,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isWin ? AppTheme.success : AppTheme.error,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Opponent + timeframe
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'vs $opponent',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  timeframe,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),

          // PnL
          Text(
            pnl,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isWin ? AppTheme.success : AppTheme.error,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Transaction Row (deposits / withdrawals)
// ═══════════════════════════════════════════════════════════════════════════════

class _TransactionRow extends StatelessWidget {
  final Transaction tx;

  const _TransactionRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isDeposit = tx.type == TransactionType.deposit;
    final color = isDeposit ? AppTheme.solanaGreen : AppTheme.error;
    final icon = isDeposit
        ? Icons.arrow_downward_rounded
        : Icons.arrow_upward_rounded;
    final label = isDeposit ? 'Deposit' : 'Withdrawal';
    final sign = isDeposit ? '+' : '-';

    Color statusColor;
    String statusLabel;
    switch (tx.status) {
      case TransactionStatus.confirmed:
        statusColor = AppTheme.success;
        statusLabel = 'Confirmed';
        break;
      case TransactionStatus.failed:
        statusColor = AppTheme.error;
        statusLabel = 'Failed';
        break;
      case TransactionStatus.pending:
        statusColor = AppTheme.warning;
        statusLabel = 'Pending';
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),

          // Label + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM d, yyyy · h:mm a').format(tx.createdAt),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              statusLabel,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Amount
          Text(
            '$sign\$${tx.amount.toStringAsFixed(2)}',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
