import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../providers/portfolio_provider.dart';

/// Shows the deposit modal with platform vault address + QR code.
void showDepositModal(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => const _DepositModal(),
  );
}

enum _Step { address, success }

class _DepositModal extends ConsumerStatefulWidget {
  const _DepositModal();

  @override
  ConsumerState<_DepositModal> createState() => _DepositModalState();
}

class _DepositModalState extends ConsumerState<_DepositModal> {
  _Step _step = _Step.address;
  String? _vaultAddress;
  bool _loadingVault = true;
  String? _error;
  final _txController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadVaultAddress();
  }

  @override
  void dispose() {
    _txController.dispose();
    super.dispose();
  }

  Future<void> _loadVaultAddress() async {
    final address =
        await ref.read(portfolioProvider.notifier).getVaultAddress();
    if (mounted) {
      setState(() {
        _vaultAddress = address;
        _loadingVault = false;
      });
    }
  }

  void _copyAddress(String address) {
    Clipboard.setData(ClipboardData(text: address));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Vault address copied to clipboard',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        backgroundColor: AppTheme.textPrimary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmDeposit() async {
    final sig = _txController.text.trim();
    if (sig.isEmpty) {
      setState(() => _error = 'Please enter the transaction signature');
      return;
    }
    setState(() => _error = null);

    final success =
        await ref.read(portfolioProvider.notifier).confirmDeposit(sig);

    if (success && mounted) {
      // Refresh both on-chain and platform balances.
      ref.read(walletProvider.notifier).refreshBalance();
      setState(() => _step = _Step.success);
    } else if (mounted) {
      final state = ref.read(portfolioProvider);
      setState(() => _error = state.depositError ?? 'Failed to confirm deposit');
    }
  }

  Future<void> _pasteSignature() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _txController.text = data!.text!.trim();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final portfolio = ref.watch(portfolioProvider);

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
          child: _step == _Step.success
              ? _buildSuccess()
              : _buildMain(wallet, portfolio),
        ),
      ),
    );
  }

  Widget _buildMain(dynamic wallet, dynamic portfolio) {
    final address = _vaultAddress ?? '';

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
                      'Send USDC to the platform vault',
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

        if (_loadingVault)
          const Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(),
          )
        else if (address.isEmpty)
          Padding(
            padding: const EdgeInsets.all(28),
            child: Text(
              'Could not load vault address. Please try again later.',
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.error),
              textAlign: TextAlign.center,
            ),
          )
        else ...[
          // ── QR Code ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: QrImageView(
              data: address,
              version: QrVersions.auto,
              size: 180,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Vault Address ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: GestureDetector(
              onTap: () => _copyAddress(address),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
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
                          address,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.copy_rounded,
                        size: 16,
                        color: AppTheme.solanaPurple,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Instructions ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.info.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: AppTheme.info),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Send USDC on Solana to this vault address. After sending, paste your transaction signature below to credit your balance.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.info,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Tx Signature Input ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transaction Signature',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _txController,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Paste transaction signature...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textTertiary,
                    ),
                    suffixIcon: IconButton(
                      onPressed: _pasteSignature,
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

          const SizedBox(height: 16),

          // ── Error ──────────────────────────────────────────────────
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

          // ── Confirm Button ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: portfolio.isDepositing ? null : _confirmDeposit,
                child: portfolio.isDepositing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Confirm Deposit',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),

          // ── Current Balance ─────────────────────────────
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
                  '\$${wallet.platformBalance.toStringAsFixed(2)} USDC',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.solanaGreenDark,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),
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
          'Your platform balance has been credited.',
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
