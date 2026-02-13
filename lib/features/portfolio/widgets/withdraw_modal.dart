import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../providers/portfolio_provider.dart';

/// Shows the withdraw modal with amount + address input.
void showWithdrawModal(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => const _WithdrawModal(),
  );
}

enum _Step { form, success }

class _WithdrawModal extends ConsumerStatefulWidget {
  const _WithdrawModal();

  @override
  ConsumerState<_WithdrawModal> createState() => _WithdrawModalState();
}

class _WithdrawModalState extends ConsumerState<_WithdrawModal> {
  final _amountController = TextEditingController();
  final _addressController = TextEditingController();
  String? _localError;
  _Step _step = _Step.form;
  String? _txSignature;

  @override
  void dispose() {
    _amountController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _onWithdraw() async {
    final amountText = _amountController.text.trim();
    final address = _addressController.text.trim();

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() => _localError = 'Enter a valid amount');
      return;
    }
    if (amount < 1) {
      setState(() => _localError = 'Minimum withdrawal is 1 USDC');
      return;
    }

    final balance = ref.read(walletProvider).usdcBalance ?? 0;
    if (amount > balance) {
      setState(() => _localError = 'Insufficient balance');
      return;
    }

    if (!PortfolioNotifier.isValidSolanaAddress(address)) {
      setState(() => _localError = 'Invalid Solana address');
      return;
    }

    setState(() => _localError = null);

    final success =
        await ref.read(portfolioProvider.notifier).withdraw(amount, address);

    if (success && mounted) {
      final state = ref.read(portfolioProvider);
      setState(() {
        _step = _Step.success;
        _txSignature = state.transactions.isNotEmpty
            ? state.transactions.first.signature
            : null;
      });
    } else if (mounted) {
      final state = ref.read(portfolioProvider);
      setState(() => _localError = state.withdrawError);
    }
  }

  void _fillMax() {
    final balance = ref.read(walletProvider).usdcBalance ?? 0;
    _amountController.text = balance.toStringAsFixed(2);
  }

  Future<void> _pasteAddress() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _addressController.text = data!.text!.trim();
    }
  }

  void _openExplorer() {
    if (_txSignature != null) {
      launchUrl(Uri.parse(
          'https://explorer.solana.com/tx/$_txSignature?cluster=devnet'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final portfolio = ref.watch(portfolioProvider);
    final wallet = ref.watch(walletProvider);
    final error = _localError ?? portfolio.withdrawError;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 440,
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            boxShadow: AppTheme.shadowLg,
          ),
          child: _step == _Step.success
              ? _buildSuccess()
              : _buildForm(wallet, portfolio, error),
        ),
      ),
    );
  }

  Widget _buildForm(dynamic wallet, dynamic portfolio, String? error) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Header ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_upward_rounded,
                  color: AppTheme.error,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Withdraw USDC',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Send USDC to an external wallet',
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
        const SizedBox(height: 20),

        // ── Amount Field ───────────────────────────────────────────
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
                  Text(
                    'Balance: \$${wallet.usdcBalance?.toStringAsFixed(2) ?? '0.00'}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.textTertiary,
                  ),
                  prefixText: '\$ ',
                  prefixStyle: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextButton(
                      onPressed: _fillMax,
                      child: Text(
                        'MAX',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.solanaPurple,
                        ),
                      ),
                    ),
                  ),
                  suffixIconConstraints:
                      const BoxConstraints(minHeight: 0, minWidth: 0),
                  filled: true,
                  fillColor: AppTheme.background,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
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

        // ── Destination Address ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Destination Address',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _addressController,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Solana wallet address',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textTertiary,
                  ),
                  suffixIcon: IconButton(
                    onPressed: _pasteAddress,
                    icon: const Icon(Icons.content_paste_rounded,
                        size: 18),
                    color: AppTheme.solanaPurple,
                    splashRadius: 18,
                  ),
                  filled: true,
                  fillColor: AppTheme.background,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
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

        const SizedBox(height: 14),

        // ── Fee estimate ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Network Fee',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                  ),
                ),
                Text(
                  '~0.000005 SOL',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── Error ──────────────────────────────────────────────────
        if (error != null)
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
                error,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.error,
                ),
              ),
            ),
          ),

        // ── Withdraw Button ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: portfolio.isWithdrawing ? null : _onWithdraw,
              child: portfolio.isWithdrawing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Withdraw',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 36),

        // Success icon
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
          'Withdrawal Sent',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your USDC is on its way.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),

        const SizedBox(height: 20),

        // Tx signature
        if (_txSignature != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: GestureDetector(
              onTap: _openExplorer,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _txSignature!,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppTheme.textTertiary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'View on Explorer',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.solanaPurple,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
