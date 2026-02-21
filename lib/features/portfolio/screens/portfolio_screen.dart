import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/config/environment.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../features/arena/providers/trading_provider.dart';
import '../../../features/play/providers/queue_provider.dart';
import '../../../features/wallet/models/wallet_state.dart';
import '../../../features/wallet/providers/wallet_provider.dart';
import '../../../features/wallet/widgets/connect_wallet_modal.dart';
import '../models/transaction_models.dart';
import '../providers/portfolio_provider.dart';
import '../widgets/deposit_modal.dart';
import '../widgets/withdraw_modal.dart';

/// Portfolio screen — wallet balance, open positions, match history, PnL chart.
class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({super.key});

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> {
  String? _lastAddress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fetchForCurrentWallet();
    });
  }

  void _fetchForCurrentWallet() {
    final wallet = ref.read(walletProvider);
    if (wallet.isConnected && wallet.address != null) {
      _lastAddress = wallet.address;
      ref.read(queueProvider.notifier).fetchUserStats(wallet.address!);
      ref.read(portfolioProvider.notifier).fetchMatchHistory();
      ref.read(portfolioProvider.notifier).fetchTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-fetch portfolio data when wallet address changes (switching wallets).
    ref.listen(walletProvider, (WalletState? prev, WalletState next) {
      if (next.isConnected && next.address != null && next.address != _lastAddress) {
        // New wallet connected — clear stale data and re-fetch.
        ref.read(portfolioProvider.notifier).reset();
        _fetchForCurrentWallet();
      } else if (!next.isConnected && (prev?.isConnected ?? false)) {
        // Wallet disconnected — clear portfolio data.
        ref.read(portfolioProvider.notifier).reset();
        _lastAddress = null;
      }
    });
    final wallet = ref.watch(walletProvider);
    final portfolio = ref.watch(portfolioProvider);
    final queue = ref.watch(queueProvider);
    final trading = ref.watch(tradingProvider);
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
                platformBalance: wallet.platformBalance,
                frozenBalance: wallet.frozenBalance,
                isMobile: isMobile,
                inPlay: trading.matchActive
                    ? (TradingState.demoBalance - trading.balance).abs()
                    : 0,
                totalPnl: queue.userPnl,
                wins: queue.userWins,
                losses: queue.userLosses,
                winRate: queue.userWinRate,
                onDeposit: () => showDepositModal(context),
                onWithdraw: () => showWithdrawModal(context),
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
              child: trading.matchActive
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusLg),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: _ActiveMatchRow(
                        opponent:
                            trading.opponentGamerTag ?? 'Opponent',
                        duration:
                            '${(trading.matchTimeRemainingSeconds / 60).ceil()}m',
                        yourPnl: _formatPnlPercent(
                            trading.equity, trading.initialBalance),
                        oppPnl: _formatPnlPercent(
                            trading.opponentEquity,
                            trading.initialBalance),
                        timeLeft:
                            '${_formatTimeLeft(trading.matchTimeRemainingSeconds)} left',
                        yourPnlPositive:
                            trading.equity >= trading.initialBalance,
                        oppPnlPositive: trading.opponentEquity >=
                            trading.initialBalance,
                      ),
                    )
                  : Container(
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
                          Icon(Icons.sports_esports_outlined,
                              size: 36, color: AppTheme.textTertiary),
                          const SizedBox(height: 10),
                          Text(
                            'No active matches',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ],
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
              child: portfolio.matchHistory.isEmpty
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
                          Icon(Icons.history_rounded,
                              size: 36, color: AppTheme.textTertiary),
                          const SizedBox(height: 10),
                          Text(
                            'No matches played yet',
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
                              i < portfolio.matchHistory.length;
                              i++) ...[
                            if (i > 0) const Divider(height: 1),
                            _HistoryRow(
                              opponent:
                                  portfolio.matchHistory[i].opponent,
                              duration:
                                  portfolio.matchHistory[i].duration,
                              result: portfolio.matchHistory[i].result,
                              pnl: _formatPnlDollar(
                                  portfolio.matchHistory[i].pnl),
                            ),
                          ],
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

  static String _formatPnlPercent(double equity, double initial) {
    if (initial <= 0) return '0.0%';
    final pct = (equity - initial) / initial * 100;
    final sign = pct >= 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(1)}%';
  }

  static String _formatPnlDollar(double pnl) {
    final sign = pnl >= 0 ? '+' : '-';
    return '$sign\$${pnl.abs().toStringAsFixed(2)}';
  }

  static String _formatTimeLeft(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${(seconds / 60).ceil()}m';
    return '${(seconds / 3600).ceil()}h';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Portfolio Hero Card
// ═══════════════════════════════════════════════════════════════════════════════

class _PortfolioHero extends StatelessWidget {
  final double platformBalance;
  final double frozenBalance;
  final bool isMobile;
  final double inPlay;
  final double totalPnl;
  final int wins;
  final int losses;
  final int winRate;
  final VoidCallback onDeposit;
  final VoidCallback onWithdraw;

  const _PortfolioHero({
    required this.platformBalance,
    required this.isMobile,
    required this.onDeposit,
    required this.onWithdraw,
    this.frozenBalance = 0,
    this.inPlay = 0,
    this.totalPnl = 0,
    this.wins = 0,
    this.losses = 0,
    this.winRate = 0,
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
                            Environment.useDevnet ? 'Devnet' : 'Mainnet',
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
                  '\$${platformBalance.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: isMobile ? 36 : 48,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Platform Balance',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                    if (frozenBalance > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '\$${frozenBalance.toStringAsFixed(2)} in play',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.warning,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 20),

                // ── Deposit / Withdraw buttons ──
                Row(
                  children: [
                    Expanded(
                      child: _HeroButton(
                        label: 'Deposit',
                        icon: Icons.arrow_downward_rounded,
                        color: AppTheme.solanaGreen,
                        onTap: onDeposit,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _HeroButton(
                        label: 'Withdraw',
                        icon: Icons.arrow_upward_rounded,
                        color: AppTheme.solanaPurpleLight,
                        onTap: onWithdraw,
                      ),
                    ),
                  ],
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
                                        value: '\$${inPlay.toStringAsFixed(2)}',
                                        color: AppTheme.solanaPurpleLight)),
                                _statDivider(),
                                Expanded(
                                    child: _HeroStat(
                                        label: 'Total PnL',
                                        value: '${totalPnl >= 0 ? '+' : '-'}\$${totalPnl.abs().toStringAsFixed(2)}',
                                        color: totalPnl >= 0 ? AppTheme.success : AppTheme.error)),
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
                                        value: '${wins}W - ${losses}L',
                                        color: AppTheme.solanaGreen)),
                                _statDivider(),
                                Expanded(
                                    child: _HeroStat(
                                        label: 'Win Rate',
                                        value: '$winRate%',
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
                                    value: '\$${inPlay.toStringAsFixed(2)}',
                                    color: AppTheme.solanaPurpleLight)),
                            _statDivider(),
                            Expanded(
                                child: _HeroStat(
                                    label: 'Total PnL',
                                    value: '${totalPnl >= 0 ? '+' : '-'}\$${totalPnl.abs().toStringAsFixed(2)}',
                                    color: totalPnl >= 0 ? AppTheme.success : AppTheme.error)),
                            _statDivider(),
                            Expanded(
                                child: _HeroStat(
                                    label: 'Record',
                                    value: '${wins}W - ${losses}L',
                                    color: AppTheme.solanaGreen)),
                            _statDivider(),
                            Expanded(
                                child: _HeroStat(
                                    label: 'Win Rate',
                                    value: '$winRate%',
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
// Hero Button (Deposit / Withdraw)
// ═══════════════════════════════════════════════════════════════════════════════

class _HeroButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HeroButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
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
// Active Match Row
// ═══════════════════════════════════════════════════════════════════════════════

class _ActiveMatchRow extends StatelessWidget {
  final String opponent;
  final String duration;
  final String yourPnl;
  final String oppPnl;
  final String timeLeft;
  final bool yourPnlPositive;
  final bool oppPnlPositive;

  const _ActiveMatchRow({
    required this.opponent,
    required this.duration,
    required this.yourPnl,
    required this.oppPnl,
    required this.timeLeft,
    this.yourPnlPositive = true,
    this.oppPnlPositive = false,
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
                  color: yourPnlPositive ? AppTheme.success : AppTheme.error,
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
                'VS  $duration',
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
                  color: oppPnlPositive ? AppTheme.success : AppTheme.error,
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
  final String duration;
  final String result;
  final String pnl;

  const _HistoryRow({
    required this.opponent,
    required this.duration,
    required this.result,
    required this.pnl,
  });

  @override
  Widget build(BuildContext context) {
    final isWin = result == 'WIN';
    final isTie = result == 'TIE';

    final Color badgeColor = isWin
        ? AppTheme.success
        : isTie
            ? AppTheme.warning
            : AppTheme.error;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // Result badge
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                result,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: badgeColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Opponent + duration
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
                  duration,
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
              color: badgeColor,
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
    final (Color color, IconData icon, String label, String sign) =
        _txStyle(tx.type);

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

  static (Color, IconData, String, String) _txStyle(TransactionType type) {
    switch (type) {
      case TransactionType.deposit:
        return (AppTheme.solanaGreen, Icons.arrow_downward_rounded, 'Deposit', '+');
      case TransactionType.withdraw:
        return (AppTheme.error, Icons.arrow_upward_rounded, 'Withdrawal', '-');
      case TransactionType.matchWin:
        return (AppTheme.success, Icons.emoji_events_rounded, 'Match Win', '+');
      case TransactionType.matchLoss:
        return (AppTheme.error, Icons.trending_down_rounded, 'Match Loss', '-');
      case TransactionType.matchTie:
        return (AppTheme.warning, Icons.handshake_rounded, 'Match Tie', '');
      case TransactionType.matchFreeze:
        return (AppTheme.solanaPurpleLight, Icons.lock_rounded, 'Bet Locked', '-');
      case TransactionType.matchUnfreeze:
        return (AppTheme.solanaPurpleLight, Icons.lock_open_rounded, 'Bet Unlocked', '+');
    }
  }
}
