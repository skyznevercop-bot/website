import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/wallet_provider.dart';
import 'connect_wallet_modal.dart';

/// Top-bar button that opens the wallet connection modal.
class ConnectWalletButton extends ConsumerStatefulWidget {
  const ConnectWalletButton({super.key});

  @override
  ConsumerState<ConnectWalletButton> createState() =>
      _ConnectWalletButtonState();
}

class _ConnectWalletButtonState extends ConsumerState<ConnectWalletButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: wallet.isConnecting
            ? null
            : () => showConnectWalletModal(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: _hovered && !wallet.isConnecting
                ? const LinearGradient(
                    colors: [AppTheme.solanaPurpleDark, AppTheme.solanaPurple],
                  )
                : AppTheme.purpleGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: _hovered && !wallet.isConnecting
                ? [
                    BoxShadow(
                      color: AppTheme.solanaPurple.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (wallet.isConnecting) ...[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Connecting...',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ] else ...[
                const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Connect Wallet',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
