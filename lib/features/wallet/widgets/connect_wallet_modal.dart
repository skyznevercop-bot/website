import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../models/wallet_state.dart';
import '../providers/wallet_provider.dart';

/// Shows the wallet connection modal as a centered dialog.
void showConnectWalletModal(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => const _ConnectWalletModal(),
  );
}

class _ConnectWalletModal extends ConsumerWidget {
  const _ConnectWalletModal();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);

    // Auto-close modal on successful connection
    ref.listen<WalletState>(walletProvider, (prev, next) {
      if (next.isConnected && !(prev?.isConnected ?? false)) {
        Navigator.of(context).pop();
      }
    });

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 420,
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            boxShadow: AppTheme.shadowLg,
          ),
          child: Column(
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
                        gradient: AppTheme.purpleGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Connect Wallet',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Choose a wallet to enter the arena',
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
              const SizedBox(height: 8),

              // ── Wallet Options ─────────────────────────────────────────
              _WalletOption(
                name: 'Phantom',
                svgAsset: 'assets/wallets/phantom.svg',
                walletType: WalletType.phantom,
                isConnecting: wallet.isConnecting &&
                    wallet.walletType == WalletType.phantom,
              ),
              _WalletOption(
                name: 'Solflare',
                svgAsset: 'assets/wallets/solflare.svg',
                walletType: WalletType.solflare,
                isConnecting: wallet.isConnecting &&
                    wallet.walletType == WalletType.solflare,
              ),
              _WalletOption(
                name: 'Backpack',
                svgAsset: 'assets/wallets/backpack.svg',
                walletType: WalletType.backpack,
                isConnecting: wallet.isConnecting &&
                    wallet.walletType == WalletType.backpack,
              ),
              _WalletOption(
                name: 'Jupiter',
                svgAsset: 'assets/wallets/jupiter.svg',
                walletType: WalletType.jupiter,
                isConnecting: wallet.isConnecting &&
                    wallet.walletType == WalletType.jupiter,
              ),

              const SizedBox(height: 8),
              const Divider(height: 1),

              // ── Error message ──────────────────────────────────────────
              if (wallet.hasError && wallet.errorMessage != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Text(
                      wallet.errorMessage!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.error,
                      ),
                    ),
                  ),
                ),
              ],

              // ── Footer ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'By connecting, you agree to the Terms of Service and Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                  ),
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
// Single Wallet Option Row
// ═══════════════════════════════════════════════════════════════════════════════

class _WalletOption extends ConsumerStatefulWidget {
  final String name;
  final String svgAsset;
  final WalletType walletType;
  final bool isConnecting;

  const _WalletOption({
    required this.name,
    required this.svgAsset,
    required this.walletType,
    this.isConnecting = false,
  });

  @override
  ConsumerState<_WalletOption> createState() => _WalletOptionState();
}

class _WalletOptionState extends ConsumerState<_WalletOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.isConnecting
            ? null
            : () => ref.read(walletProvider.notifier).connect(widget.walletType),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _hovered
                ? AppTheme.solanaPurple.withValues(alpha: 0.04)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: _hovered ? AppTheme.solanaPurple.withValues(alpha: 0.2) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              // Wallet logo
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SvgPicture.asset(
                  widget.svgAsset,
                  width: 40,
                  height: 40,
                ),
              ),
              const SizedBox(width: 14),

              // Wallet name
              Expanded(
                child: Text(
                  widget.name,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),

              // Connect / spinner
              if (widget.isConnecting)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.solanaPurple,
                  ),
                )
              else
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: _hovered
                      ? AppTheme.solanaPurple
                      : AppTheme.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
