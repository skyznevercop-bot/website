import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/wallet_provider.dart';

/// Profile dropdown shown in the top bar when wallet is connected.
/// Displays avatar, gamer tag, wallet address, balance, and actions.
class WalletDropdown extends ConsumerStatefulWidget {
  const WalletDropdown({super.key});

  @override
  ConsumerState<WalletDropdown> createState() => _WalletDropdownState();
}

class _WalletDropdownState extends ConsumerState<WalletDropdown> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: PopupMenuButton<String>(
        offset: const Offset(0, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        color: AppTheme.surface,
        elevation: 8,
        shadowColor: Colors.black26,
        onSelected: (value) => _handleAction(value, context),
        itemBuilder: (context) => [
          // ── Profile Header ─────────────────────────────────────────
          PopupMenuItem<String>(
            enabled: false,
            child: SizedBox(
              width: 240,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildAvatar(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              wallet.gamerTag ?? 'Set Gamer Tag',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              wallet.shortAddress,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Platform balance (what you play with)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.solanaPurple.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppTheme.radiusSm),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.sports_esports_rounded,
                          size: 18,
                          color: AppTheme.solanaPurple,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Platform',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ),
                        wallet.isBalanceLoading && wallet.platformBalance == 0
                            ? _buildBalanceShimmer(
                                color: AppTheme.solanaPurple)
                            : Text(
                                '\$${wallet.availableBalance.toStringAsFixed(2)} USDC',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.solanaPurple,
                                ),
                              ),
                      ],
                    ),
                  ),
                  // Wallet USDC balance (what you can deposit)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.solanaGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(AppTheme.radiusSm),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 18,
                          color: AppTheme.solanaGreenDark,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Wallet',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ),
                        wallet.usdcBalance == null
                            ? _buildBalanceShimmer(
                                color: AppTheme.solanaGreenDark)
                            : Text(
                                '\$${wallet.usdcBalance!.toStringAsFixed(2)} USDC',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.solanaGreenDark,
                                ),
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          ref
                              .read(walletProvider.notifier)
                              .refreshBalance();
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.refresh_rounded,
                              size: 14,
                              color: AppTheme.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Refresh',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const PopupMenuDivider(),

          // ── Menu Items ─────────────────────────────────────────────
          _buildMenuItem(
            icon: Icons.account_circle_rounded,
            label: 'My Profile',
            value: 'profile',
          ),
          _buildMenuItem(
            icon: Icons.person_rounded,
            label: 'Edit Gamer Tag',
            value: 'edit_tag',
          ),
          _buildMenuItem(
            icon: Icons.copy_rounded,
            label: 'Copy Address',
            value: 'copy_address',
          ),
          _buildMenuItem(
            icon: Icons.people_rounded,
            label: 'Friends',
            value: 'friends',
          ),
          _buildMenuItem(
            icon: Icons.pie_chart_rounded,
            label: 'Portfolio',
            value: 'portfolio',
          ),
          PopupMenuItem<String>(
            value: 'referrals',
            child: Row(
              children: [
                Icon(Icons.card_giftcard_rounded,
                    size: 18, color: AppTheme.textSecondary),
                const SizedBox(width: 12),
                Text(
                  'Referrals',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          const PopupMenuDivider(),

          _buildMenuItem(
            icon: Icons.logout_rounded,
            label: 'Disconnect',
            value: 'disconnect',
            color: AppTheme.error,
          ),
        ],
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered
                ? AppTheme.solanaPurple.withValues(alpha: 0.06)
                : AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: _hovered
                  ? AppTheme.solanaPurple.withValues(alpha: 0.2)
                  : AppTheme.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAvatar(size: 28),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wallet.gamerTag ?? wallet.shortAddress,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      wallet.isBalanceLoading && wallet.platformBalance == 0
                          ? _buildSmallShimmer()
                          : Text(
                              '\$${wallet.availableBalance.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.solanaPurple,
                              ),
                            ),
                      Text(
                        '  ·  ',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.textTertiary.withValues(alpha: 0.4),
                        ),
                      ),
                      wallet.usdcBalance == null
                          ? _buildSmallShimmer()
                          : Text(
                              '\$${wallet.usdcBalance!.toStringAsFixed(2)} USDC',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: AppTheme.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar({double size = 36}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppTheme.purpleGradient,
        borderRadius: BorderRadius.circular(size / 2.5),
      ),
      child: Icon(
        Icons.person_rounded,
        color: Colors.white,
        size: size * 0.55,
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? AppTheme.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _handleAction(String action, BuildContext context) {
    switch (action) {
      case 'profile':
        final address = ref.read(walletProvider).address;
        if (address != null) {
          context.go('/profile/$address');
        }
        break;
      case 'disconnect':
        ref.read(walletProvider.notifier).disconnect();
        break;
      case 'copy_address':
        final address = ref.read(walletProvider).address;
        if (address != null) {
          Clipboard.setData(ClipboardData(text: address));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Address copied to clipboard',
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
        break;
      case 'edit_tag':
        _showGamerTagDialog(context);
        break;
      case 'referrals':
        context.go(AppConstants.referralRoute);
        break;
      case 'friends':
        context.go(AppConstants.friendsRoute);
        break;
      case 'portfolio':
        context.go(AppConstants.portfolioRoute);
        break;
      case 'learn':
        context.go(AppConstants.learnRoute);
        break;
    }
  }

  Widget _buildBalanceShimmer({required Color color}) {
    return SizedBox(
      width: 80,
      height: 16,
      child: _PulsingContainer(color: color.withValues(alpha: 0.15)),
    );
  }

  Widget _buildSmallShimmer() {
    return SizedBox(
      width: 50,
      height: 12,
      child: _PulsingContainer(
          color: AppTheme.textTertiary.withValues(alpha: 0.15)),
    );
  }

  void _showGamerTagDialog(BuildContext context) {
    final controller = TextEditingController(
      text: ref.read(walletProvider).gamerTag ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        ),
        title: Text(
          'Set Gamer Tag',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(
            hintText: 'Enter your gamer tag...',
            counterText: '',
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              ref.read(walletProvider.notifier).setGamerTag(value.trim());
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                ref.read(walletProvider.notifier).setGamerTag(value);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

/// Pulsing shimmer placeholder for loading balance values.
class _PulsingContainer extends StatefulWidget {
  final Color color;
  const _PulsingContainer({required this.color});

  @override
  State<_PulsingContainer> createState() => _PulsingContainerState();
}

class _PulsingContainerState extends State<_PulsingContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          color:
              widget.color.withValues(alpha: 0.1 + _controller.value * 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
