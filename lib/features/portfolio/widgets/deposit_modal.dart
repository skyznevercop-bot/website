import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../providers/portfolio_provider.dart';

/// Shows the one-click deposit modal.
void showDepositModal(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => const _DepositModal(),
  );
}

enum _Step { form, sending, success }

class _DepositModal extends ConsumerStatefulWidget {
  const _DepositModal();

  @override
  ConsumerState<_DepositModal> createState() => _DepositModalState();
}

class _DepositModalState extends ConsumerState<_DepositModal> {
  _Step _step = _Step.form;
  String? _error;
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
      _step = _Step.sending;
      _depositedAmount = amount;
    });

    final success =
        await ref.read(portfolioProvider.notifier).deposit(amount);

    if (!mounted) return;

    if (success) {
      setState(() => _step = _Step.success);
    } else {
      final state = ref.read(portfolioProvider);
      setState(() {
        _step = _Step.form;
        _error = state.depositError ?? 'Deposit failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final onChainBalance = wallet.usdcBalance ?? 0;

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
          child: switch (_step) {
            _Step.form => _buildForm(onChainBalance),
            _Step.sending => _buildSending(),
            _Step.success => _buildSuccess(),
          },
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

  Widget _buildSending() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 48),
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
          'Confirm in your wallet',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Approve the transaction in your wallet popup...',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 48),
      ],
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
