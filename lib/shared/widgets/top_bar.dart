import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../features/wallet/widgets/connect_wallet_button.dart';
import '../../features/wallet/widgets/wallet_dropdown.dart';
import '../../features/wallet/providers/wallet_provider.dart';

/// Persistent top navigation bar — chess.com-inspired layout.
///
/// Left:  Logo + 4 nav tabs (Play, Learn, Clan, Leaderboard)
/// Right: Wallet connect / profile dropdown
class TopBar extends ConsumerWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = Responsive.isMobile(context);

    return Container(
      height: AppConstants.topBarHeight,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
        child: Row(
          children: [
            // ── Logo ──────────────────────────────────────────────────────
            _Logo(compact: isMobile),
            if (!isMobile) const SizedBox(width: 32),

            // ── Nav Tabs (hidden on mobile) ──────────────────────────────
            if (!isMobile) ...[
              const _NavTab(
                label: 'Play',
                icon: Icons.sports_esports_rounded,
                path: AppConstants.playRoute,
              ),
              const _NavTab(
                label: 'Clan',
                icon: Icons.groups_rounded,
                path: AppConstants.clanRoute,
              ),
              const _NavTab(
                label: 'Leaderboard',
                icon: Icons.leaderboard_rounded,
                path: AppConstants.leaderboardRoute,
              ),
              const _NavTab(
                label: 'Portfolio',
                icon: Icons.pie_chart_rounded,
                path: AppConstants.portfolioRoute,
              ),
              const _NavTab(
                label: 'Learn',
                icon: Icons.school_rounded,
                path: AppConstants.learnRoute,
              ),
              const _MoreMenuButton(),
            ],

            const Spacer(),

            // ── Wallet / Profile ─────────────────────────────────────────
            const _WalletArea(),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Logo
// ═══════════════════════════════════════════════════════════════════════════════

class _Logo extends StatelessWidget {
  final bool compact;
  const _Logo({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go(AppConstants.playRoute),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo image
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/logo.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 10),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Sol',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    TextSpan(
                      text: 'Fight',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.solanaPurple,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Navigation Tab
// ═══════════════════════════════════════════════════════════════════════════════

class _NavTab extends StatefulWidget {
  final String label;
  final IconData icon;
  final String path;

  const _NavTab({
    required this.label,
    required this.icon,
    required this.path,
  });

  @override
  State<_NavTab> createState() => _NavTabState();
}

class _NavTabState extends State<_NavTab> {
  bool _hovered = false;

  bool _isActive(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    return location == widget.path;
  }

  @override
  Widget build(BuildContext context) {
    final active = _isActive(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.go(widget.path),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? AppTheme.solanaPurple.withValues(alpha: 0.1)
                : _hovered
                    ? AppTheme.solanaPurple.withValues(alpha: 0.05)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 20,
                color: active
                    ? AppTheme.solanaPurple
                    : _hovered
                        ? AppTheme.solanaPurple
                        : AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active
                      ? AppTheme.solanaPurple
                      : _hovered
                          ? AppTheme.solanaPurple
                          : AppTheme.textSecondary,
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
// "..." More Menu Button
// ═══════════════════════════════════════════════════════════════════════════════

class _MoreMenuButton extends StatefulWidget {
  const _MoreMenuButton();

  @override
  State<_MoreMenuButton> createState() => _MoreMenuButtonState();
}

class _MoreMenuButtonState extends State<_MoreMenuButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: PopupMenuButton<String>(
        offset: const Offset(0, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        color: AppTheme.surface,
        elevation: 8,
        shadowColor: Colors.black26,
        onSelected: (value) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Coming soon!',
                  style: GoogleFonts.inter(fontSize: 13)),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              backgroundColor: AppTheme.textPrimary,
              duration: const Duration(seconds: 2),
            ),
          );
        },
        itemBuilder: (context) => [
          _moreMenuItem(Icons.help_outline_rounded, 'Help Center', 'help'),
          _moreMenuItem(Icons.description_rounded, 'Rules & FAQ', 'rules'),
          _moreMenuItem(Icons.chat_bubble_outline_rounded, 'Feedback', 'feedback'),
          const PopupMenuDivider(),
          _moreMenuItem(Icons.info_outline_rounded, 'About SolFight', 'about'),
        ],
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered
                ? AppTheme.solanaPurple.withValues(alpha: 0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Icon(
            Icons.more_horiz_rounded,
            size: 22,
            color: _hovered ? AppTheme.solanaPurple : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _moreMenuItem(IconData icon, String label, String value) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Wallet Area — shows connect button or profile dropdown
// ═══════════════════════════════════════════════════════════════════════════════

class _WalletArea extends ConsumerWidget {
  const _WalletArea();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);

    if (wallet.isConnected) {
      return const WalletDropdown();
    }
    return const ConnectWalletButton();
  }
}
