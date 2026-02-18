import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../models/transaction_models.dart';
import '../providers/portfolio_provider.dart';

/// Shows the one-click deposit modal.
void showDepositModal(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => const _DepositModal(),
  );
}

class _DepositModal extends ConsumerStatefulWidget {
  const _DepositModal();

  @override
  ConsumerState<_DepositModal> createState() => _DepositModalState();
}

class _DepositModalState extends ConsumerState<_DepositModal> {
  String? _error;
  bool _showForm = true;
  final _amountController = TextEditingController();
  double _depositedAmount = 0;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _setMax() {
    final wallet = ref.read(walletProvider);
    final balance = wallet.usdcBalance ?? 0;
    _amountController.text = balance.toStringAsFixed(2);
  }

  Future<void> _deposit() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      setState(() => _error = 'Please enter an amount');
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }

    setState(() {
      _error = null;
      _showForm = false;
      _depositedAmount = amount;
    });

    final success =
        await ref.read(portfolioProvider.notifier).deposit(amount);

    if (!mounted) return;

    if (!success) {
      final state = ref.read(portfolioProvider);
      setState(() {
        _showForm = true;
        _error = state.depositError ?? 'Deposit failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final onChainBalance = wallet.usdcBalance ?? 0;
    final portfolio = ref.watch(portfolioProvider);
    final step = portfolio.depositStep;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: Responsive.clampedWidth(context, 440),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            boxShadow: AppTheme.shadowLg,
          ),
          child: _showForm && step == DepositStep.idle
              ? _buildForm(onChainBalance)
              : step == DepositStep.done
                  ? _buildSuccess()
                  : _buildProgress(step),
        ),
      ),
    );
  }

  Widget _buildForm(double onChainBalance) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Header ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.solanaGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_downward_rounded,
                  color: AppTheme.solanaGreenDark,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deposit USDC',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Transfer USDC from your wallet',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                color: AppTheme.textTertiary,
                splashRadius: 20,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        const Divider(height: 1),
        const SizedBox(height: 24),

        // ── Amount Input ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Amount',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _setMax,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Text(
                        'Wallet: ${onChainBalance.toStringAsFixed(2)} USDC',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.solanaPurple,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textTertiary,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    child: Text(
                      '\$',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                  suffixIcon: TextButton(
                    onPressed: _setMax,
                    child: Text(
                      'MAX',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.solanaPurple,
                      ),
                    ),
                  ),
                  filled: true,
                  fillColor: AppTheme.background,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: BorderSide(color: AppTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: const BorderSide(
                        color: AppTheme.solanaPurple, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Error ──────────────────────────────────────────
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Text(
                _error!,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.error,
                ),
              ),
            ),
          ),

        // ── Deposit Button ─────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _deposit,
              child: Text(
                'Deposit',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),

        // ── Platform Balance ─────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          child: Row(
            children: [
              Text(
                'Platform Balance: ',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                '\$${ref.watch(walletProvider).platformBalance.toStringAsFixed(2)} USDC',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.solanaGreenDark,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  /// Step-by-step progress view driven by [DepositStep] from provider.
  Widget _buildProgress(DepositStep step) {
    final (title, subtitle, stepIndex) = switch (step) {
      DepositStep.signing => (
          'Approve in your wallet',
          'Confirm the transaction in the wallet popup...',
          0,
        ),
      DepositStep.confirming => (
          'Confirming on Solana',
          'Waiting for the transaction to confirm on-chain...',
          1,
        ),
      DepositStep.crediting => (
          'Crediting your balance',
          'Updating your platform balance...',
          2,
        ),
      _ => ('Processing...', '', 0),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 36),

        // ── Spinner ──
        const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: AppTheme.solanaPurple,
          ),
        ),

        const SizedBox(height: 24),

        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ),

        const SizedBox(height: 32),

        // ── Step indicators ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            children: [
              _stepDot(0, stepIndex, 'Sign'),
              _stepLine(0, stepIndex),
              _stepDot(1, stepIndex, 'Confirm'),
              _stepLine(1, stepIndex),
              _stepDot(2, stepIndex, 'Credit'),
            ],
          ),
        ),

        const SizedBox(height: 36),
      ],
    );
  }

  Widget _stepDot(int index, int current, String label) {
    final isActive = index == current;
    final isDone = index < current;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone
                  ? AppTheme.success
                  : isActive
                      ? AppTheme.solanaPurple
                      : AppTheme.border,
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                  : Text(
                      '${index + 1}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isActive ? Colors.white : AppTheme.textTertiary,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? AppTheme.textPrimary : AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepLine(int afterIndex, int current) {
    final isDone = afterIndex < current;
    return Container(
      height: 2,
      width: 24,
      margin: const EdgeInsets.only(bottom: 20),
      color: isDone ? AppTheme.success : AppTheme.border,
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 36),

        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            color: AppTheme.success,
            size: 36,
          ),
        ),

        const SizedBox(height: 20),

        Text(
          'Deposit Confirmed',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '\$${_depositedAmount.toStringAsFixed(2)} USDC has been credited.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),

        const SizedBox(height: 24),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }
}
