import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../../wallet/widgets/connect_wallet_modal.dart';
import '../models/referral_models.dart';
import '../providers/referral_provider.dart';

/// Referral program screen — share link, track referrals, claim rewards.
class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key});

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  @override
  void initState() {
    super.initState();
    // Generate referral code once wallet is connected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wallet = ref.read(walletProvider);
      if (wallet.isConnected && wallet.address != null) {
        final referral = ref.read(referralProvider);
        if (referral.referralCode == null) {
          ref
              .read(referralProvider.notifier)
              .generateCode(wallet.address!);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final referral = ref.watch(referralProvider);
    final isMobile = Responsive.isMobile(context);

    // Auto-generate code when wallet connects
    ref.listen(walletProvider, (prev, next) {
      if (next.isConnected &&
          next.address != null &&
          ref.read(referralProvider).referralCode == null) {
        ref.read(referralProvider.notifier).generateCode(next.address!);
      }
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),

          // Header
          Padding(
            padding: Responsive.horizontalPadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Referral Program',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Invite friends and earn USDC rewards when they join and play.',
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

          if (!wallet.isConnected) ...[
            _buildConnectCard(context),
          ] else ...[
            // Referral link + QR
            _buildReferralLinkCard(context, referral, isMobile),
            const SizedBox(height: 16),

            // Share buttons
            _buildShareRow(context, referral),
            const SizedBox(height: 24),

            // Reward rules
            _buildRewardRules(context),
            const SizedBox(height: 24),

            // Stats row
            _buildStatsRow(context, referral, isMobile),
            const SizedBox(height: 16),

            // Claim button
            _buildClaimButton(context, referral),
            const SizedBox(height: 32),

            // Referred users
            _buildReferredUsers(context, referral),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectCard(BuildContext context) {
    return Padding(
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
              'Connect your wallet to access referrals',
              style: GoogleFonts.inter(
                fontSize: 15,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => showConnectWalletModal(context),
              icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
              label: const Text('Connect Wallet'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralLinkCard(
      BuildContext context, ReferralState referral, bool isMobile) {
    final code = referral.referralCode ?? '...';
    final link = 'solfight.gg/?ref=$code';

    return Padding(
      padding: Responsive.horizontalPadding(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.border),
        ),
        child: isMobile
            ? Column(
                children: [
                  _buildQr(link),
                  const SizedBox(height: 20),
                  _buildLinkSection(link, context),
                ],
              )
            : Row(
                children: [
                  _buildQr(link),
                  const SizedBox(width: 28),
                  Expanded(child: _buildLinkSection(link, context)),
                ],
              ),
      ),
    );
  }

  Widget _buildQr(String link) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: QrImageView(
        data: 'https://$link',
        version: QrVersions.auto,
        size: 140,
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
    );
  }

  Widget _buildLinkSection(String link, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Referral Link',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Share this link with friends to earn rewards.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  link,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.solanaPurple,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: 'https://$link'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Referral link copied!',
                        style: GoogleFonts.inter(fontSize: 13),
                      ),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      backgroundColor: AppTheme.textPrimary,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                color: AppTheme.solanaPurple,
                splashRadius: 18,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShareRow(BuildContext context, ReferralState referral) {
    final code = referral.referralCode ?? '';
    final link = 'https://solfight.gg/?ref=$code';
    final text = Uri.encodeComponent(
        'Join me on SolFight - 1v1 trading battles on Solana! $link');

    return Padding(
      padding: Responsive.horizontalPadding(context),
      child: Row(
        children: [
          _ShareButton(
            label: 'Twitter / X',
            icon: Icons.alternate_email_rounded,
            color: const Color(0xFF1DA1F2),
            onTap: () => launchUrl(
                Uri.parse('https://twitter.com/intent/tweet?text=$text')),
          ),
          const SizedBox(width: 12),
          _ShareButton(
            label: 'Telegram',
            icon: Icons.send_rounded,
            color: const Color(0xFF0088CC),
            onTap: () => launchUrl(
                Uri.parse('https://t.me/share/url?url=$link&text=$text')),
          ),
          const SizedBox(width: 12),
          _ShareButton(
            label: 'WhatsApp',
            icon: Icons.chat_rounded,
            color: const Color(0xFF25D366),
            onTap: () =>
                launchUrl(Uri.parse('https://wa.me/?text=$text')),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardRules(BuildContext context) {
    return Padding(
      padding: Responsive.horizontalPadding(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: AppTheme.purpleGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.card_giftcard_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Reward Rules',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _RewardTier(
              step: '1',
              label: 'Friend joins SolFight',
              reward: 'Free',
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 10),
            _RewardTier(
              step: '2',
              label: 'Friend deposits USDC',
              reward: '+5 USDC',
              color: AppTheme.solanaGreen,
            ),
            const SizedBox(height: 10),
            _RewardTier(
              step: '3',
              label: 'Friend plays first match',
              reward: '+5 USDC',
              color: AppTheme.solanaPurple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(
      BuildContext context, ReferralState referral, bool isMobile) {
    return Padding(
      padding: Responsive.horizontalPadding(context),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _StatCard(
            title: 'Total Referrals',
            value: '${referral.referredUsers.length}',
            icon: Icons.people_rounded,
            color: AppTheme.solanaPurple,
            width: isMobile ? double.infinity : null,
          ),
          _StatCard(
            title: 'Total Earned',
            value: '\$${referral.totalEarned.toStringAsFixed(2)}',
            icon: Icons.monetization_on_rounded,
            color: AppTheme.solanaGreen,
            width: isMobile ? double.infinity : null,
          ),
          _StatCard(
            title: 'Pending Rewards',
            value: '\$${referral.pendingReward.toStringAsFixed(2)}',
            icon: Icons.access_time_rounded,
            color: AppTheme.warning,
            width: isMobile ? double.infinity : null,
          ),
        ],
      ),
    );
  }

  Widget _buildClaimButton(BuildContext context, ReferralState referral) {
    final canClaim = referral.pendingReward > 0 && !referral.isClaiming;

    return Padding(
      padding: Responsive.horizontalPadding(context),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed:
              canClaim ? ref.read(referralProvider.notifier).claimRewards : null,
          icon: referral.isClaiming
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.redeem_rounded, size: 20),
          label: Text(
            referral.isClaiming
                ? 'Claiming...'
                : 'Claim \$${referral.pendingReward.toStringAsFixed(2)} USDC',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.solanaGreen,
            foregroundColor: AppTheme.background,
            disabledBackgroundColor: AppTheme.surfaceAlt,
            disabledForegroundColor: AppTheme.textTertiary,
          ),
        ),
      ),
    );
  }

  Widget _buildReferredUsers(BuildContext context, ReferralState referral) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: Responsive.horizontalPadding(context),
          child: Text(
            'Referred Users',
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
          child: referral.referredUsers.isEmpty
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
                      Icon(Icons.person_add_rounded,
                          size: 36, color: AppTheme.textTertiary),
                      const SizedBox(height: 10),
                      Text(
                        'No referrals yet — share your link!',
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
                          i < referral.referredUsers.length;
                          i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _ReferredUserRow(user: referral.referredUsers[i]),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Share Button
// ═══════════════════════════════════════════════════════════════════════════════

class _ShareButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ShareButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends State<_ShareButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withValues(alpha: 0.12)
                : widget.color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.3)
                  : widget.color.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: widget.color),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.color,
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
// Reward Tier
// ═══════════════════════════════════════════════════════════════════════════════

class _RewardTier extends StatelessWidget {
  final String step;
  final String label;
  final String reward;
  final Color color;

  const _RewardTier({
    required this.step,
    required this.label,
    required this.reward,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              step,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Text(
          reward,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Stat Card
// ═══════════════════════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double? width;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? 200,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Referred User Row
// ═══════════════════════════════════════════════════════════════════════════════

class _ReferredUserRow extends StatelessWidget {
  final ReferredUser user;

  const _ReferredUserRow({required this.user});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusLabel;
    switch (user.status) {
      case ReferralStatus.played:
        statusColor = AppTheme.success;
        statusLabel = 'Played';
        break;
      case ReferralStatus.deposited:
        statusColor = AppTheme.solanaPurple;
        statusLabel = 'Deposited';
        break;
      case ReferralStatus.joined:
        statusColor = AppTheme.textTertiary;
        statusLabel = 'Joined';
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.solanaPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                user.gamerTag[0].toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.solanaPurple,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name
          Expanded(
            child: Text(
              user.gamerTag,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
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

          // Reward earned
          Text(
            user.rewardEarned > 0
                ? '+\$${user.rewardEarned.toStringAsFixed(0)}'
                : '-',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: user.rewardEarned > 0
                  ? AppTheme.solanaGreen
                  : AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
