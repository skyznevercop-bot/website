import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../../wallet/widgets/connect_wallet_modal.dart';
import '../models/friend_models.dart';
import '../providers/friend_provider.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _addController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _addController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final friendState = ref.watch(friendProvider);
    final isMobile = Responsive.isMobile(context);

    // Listen for error/success messages and show snackbars.
    ref.listen<FriendsState>(friendProvider, (prev, next) {
      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!, style: GoogleFonts.inter(fontSize: 13)),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
          ),
        );
        ref.read(friendProvider.notifier).clearMessages();
      }
      if (next.successMessage != null && next.successMessage != prev?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!, style: GoogleFonts.inter(fontSize: 13)),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
          ),
        );
        ref.read(friendProvider.notifier).clearMessages();
      }
    });

    if (!wallet.isConnected) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_rounded, size: 64, color: AppTheme.textTertiary),
            const SizedBox(height: 16),
            Text(
              'Connect your wallet to manage friends',
              style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => showConnectWalletModal(context),
              icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
              label: Text('Connect Wallet', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.solanaPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),

          // ── Header ──────────────────────────────────────────────
          Padding(
            padding: Responsive.horizontalPadding(context),
            child: Row(
              children: [
                Icon(Icons.people_rounded, color: AppTheme.solanaPurple, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Friends',
                  style: GoogleFonts.inter(
                    fontSize: isMobile ? 22 : 26,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                if (friendState.isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.solanaPurple),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Add Friend ──────────────────────────────────────────
          Padding(
            padding: Responsive.horizontalPadding(context),
            child: _AddFriendBar(
              controller: _addController,
              onAdd: () async {
                final address = _addController.text.trim();
                if (address.isEmpty) return;
                final ok = await ref.read(friendProvider.notifier).addFriend(address);
                if (ok) _addController.clear();
              },
            ),
          ),

          const SizedBox(height: 24),

          // ── Tabs ────────────────────────────────────────────────
          Padding(
            padding: Responsive.horizontalPadding(context),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  TabBar(
                    controller: _tabCtrl,
                    indicatorColor: AppTheme.solanaPurple,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: AppTheme.solanaPurple,
                    unselectedLabelColor: AppTheme.textSecondary,
                    labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                    unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                    dividerColor: AppTheme.border,
                    tabs: [
                      Tab(text: 'Friends (${friendState.friends.length})'),
                      _BadgeTab(
                        label: 'Requests',
                        count: friendState.requestCount,
                      ),
                      _BadgeTab(
                        label: 'Challenges',
                        count: friendState.challengeCount,
                      ),
                    ],
                  ),
                  AnimatedBuilder(
                    animation: _tabCtrl,
                    builder: (context, _) {
                      return AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        child: _buildTabContent(friendState),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(FriendsState friendState) {
    switch (_tabCtrl.index) {
      case 0:
        return _FriendsList(
          friends: friendState.friends,
          onChallenge: (friend) => _showChallengeDialog(friend),
          onRemove: (address) => ref.read(friendProvider.notifier).removeFriend(address),
        );
      case 1:
        return _RequestsList(
          requests: friendState.incomingRequests,
          onAccept: (address) => ref.read(friendProvider.notifier).acceptRequest(address),
          onDecline: (address) => ref.read(friendProvider.notifier).removeFriend(address),
        );
      case 2:
        return _ChallengesList(
          sent: friendState.sentChallenges,
          received: friendState.receivedChallenges,
          onAccept: (id) => ref.read(friendProvider.notifier).acceptChallenge(id),
          onDecline: (id) => ref.read(friendProvider.notifier).declineChallenge(id),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _showChallengeDialog(Friend friend) {
    String selectedDuration = '5m';
    double betAmount = 0;
    final betController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          ),
          title: Row(
            children: [
              Icon(Icons.sports_esports_rounded, color: AppTheme.solanaPurple, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Challenge ${friend.gamerTag}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18, color: AppTheme.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Duration', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['5m', '15m', '1h', '4h', '24h'].map((d) {
                    final selected = selectedDuration == d;
                    return ChoiceChip(
                      label: Text(d),
                      selected: selected,
                      selectedColor: AppTheme.solanaPurple.withValues(alpha: 0.2),
                      backgroundColor: AppTheme.surfaceAlt,
                      side: BorderSide(
                        color: selected ? AppTheme.solanaPurple : AppTheme.border,
                      ),
                      labelStyle: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? AppTheme.solanaPurple : AppTheme.textSecondary,
                      ),
                      onSelected: (_) => setDialogState(() => selectedDuration = d),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Text('Bet Amount (USDC)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: betController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                        style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          prefixText: '\$ ',
                          prefixStyle: GoogleFonts.inter(fontSize: 16, color: AppTheme.textSecondary),
                          hintText: '0',
                          hintStyle: GoogleFonts.inter(color: AppTheme.textTertiary),
                          filled: true,
                          fillColor: AppTheme.surfaceAlt,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            borderSide: BorderSide(color: AppTheme.solanaPurple),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        onChanged: (v) {
                          setDialogState(() {
                            betAmount = double.tryParse(v) ?? 0;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    _QuickBetButton(label: 'Free', onTap: () {
                      setDialogState(() { betAmount = 0; betController.text = '0'; });
                    }),
                    const SizedBox(width: 4),
                    _QuickBetButton(label: '\$5', onTap: () {
                      setDialogState(() { betAmount = 5; betController.text = '5'; });
                    }),
                    const SizedBox(width: 4),
                    _QuickBetButton(label: '\$10', onTap: () {
                      setDialogState(() { betAmount = 10; betController.text = '10'; });
                    }),
                  ],
                ),
                if (betAmount == 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Free match — no USDC wagered',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.solanaGreenDark),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await ref.read(friendProvider.notifier).createChallenge(
                  friend.address,
                  selectedDuration,
                  betAmount,
                );
              },
              icon: const Icon(Icons.send_rounded, size: 16),
              label: Text(
                betAmount > 0 ? 'Challenge for \$${betAmount.toStringAsFixed(0)}' : 'Send Free Challenge',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.solanaPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add Friend Bar ──────────────────────────────────────────────────────────

class _AddFriendBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onAdd;

  const _AddFriendBar({required this.controller, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Enter wallet address to add friend...',
                hintStyle: GoogleFonts.inter(fontSize: 14, color: AppTheme.textTertiary),
                prefixIcon: const Icon(Icons.person_add_rounded, size: 20, color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onSubmitted: (_) => onAdd(),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.solanaPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
            ),
            child: Text('Add', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

// ── Friends List ──────────────────────────────────────────────────────────────

class _FriendsList extends StatelessWidget {
  final List<Friend> friends;
  final void Function(Friend) onChallenge;
  final void Function(String) onRemove;

  const _FriendsList({
    required this.friends,
    required this.onChallenge,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.people_outline_rounded, size: 48, color: AppTheme.textTertiary),
              const SizedBox(height: 12),
              Text(
                'No friends yet',
                style: GoogleFonts.inter(fontSize: 15, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                'Add a friend by their wallet address above',
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textTertiary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: friends.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: AppTheme.border),
      itemBuilder: (context, i) {
        final f = friends[i];
        return _FriendTile(friend: f, onChallenge: onChallenge, onRemove: onRemove);
      },
    );
  }
}

class _FriendTile extends StatelessWidget {
  final Friend friend;
  final void Function(Friend) onChallenge;
  final void Function(String) onRemove;

  const _FriendTile({
    required this.friend,
    required this.onChallenge,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final pnlColor = friend.totalPnl >= 0 ? AppTheme.success : AppTheme.error;
    final pnlSign = friend.totalPnl >= 0 ? '+' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppTheme.purpleGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                friend.gamerTag.isNotEmpty ? friend.gamerTag[0].toUpperCase() : '?',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.gamerTag,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${friend.wins}W-${friend.losses}L',
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    if (!isMobile) ...[
                      Text(' · ', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary)),
                      Text(
                        '${friend.winRate.toStringAsFixed(0)}% WR',
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      Text(' · ', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary)),
                      Text(
                        '$pnlSign\$${friend.totalPnl.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: pnlColor),
                      ),
                    ],
                    if (friend.currentStreak > 0) ...[
                      Text(' · ', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary)),
                      Text(
                        '${friend.currentStreak} streak',
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.warning),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Actions
          TextButton.icon(
            onPressed: () => onChallenge(friend),
            icon: const Icon(Icons.sports_esports_rounded, size: 16),
            label: Text(isMobile ? '' : 'Challenge', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.solanaPurple,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: 8),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            color: AppTheme.textTertiary,
            tooltip: 'Remove friend',
            onPressed: () => onRemove(friend.address),
          ),
        ],
      ),
    );
  }
}

// ── Requests List ────────────────────────────────────────────────────────────

class _RequestsList extends StatelessWidget {
  final List<FriendRequest> requests;
  final void Function(String) onAccept;
  final void Function(String) onDecline;

  const _RequestsList({
    required this.requests,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.mail_outline_rounded, size: 48, color: AppTheme.textTertiary),
              const SizedBox(height: 12),
              Text(
                'No pending requests',
                style: GoogleFonts.inter(fontSize: 15, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: requests.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: AppTheme.border),
      itemBuilder: (context, i) {
        final r = requests[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Icon(Icons.person_rounded, color: AppTheme.textSecondary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.fromGamerTag,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                    Text(
                      '${r.fromAddress.substring(0, 8)}...',
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => onAccept(r.fromAddress),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                  minimumSize: Size.zero,
                ),
                child: Text('Accept', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => onDecline(r.fromAddress),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: BorderSide(color: AppTheme.border),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                  minimumSize: Size.zero,
                ),
                child: Text('Decline', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Challenges List ──────────────────────────────────────────────────────────

class _ChallengesList extends StatelessWidget {
  final List<Challenge> sent;
  final List<Challenge> received;
  final void Function(String) onAccept;
  final void Function(String) onDecline;

  const _ChallengesList({
    required this.sent,
    required this.received,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    if (sent.isEmpty && received.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.sports_esports_outlined, size: 48, color: AppTheme.textTertiary),
              const SizedBox(height: 12),
              Text(
                'No pending challenges',
                style: GoogleFonts.inter(fontSize: 15, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                'Challenge a friend from the Friends tab',
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textTertiary),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (received.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'RECEIVED',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textTertiary, letterSpacing: 1.2),
            ),
          ),
          ...received.map((c) => _ChallengeTile(challenge: c, isReceived: true, onAccept: onAccept, onDecline: onDecline)),
        ],
        if (sent.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'SENT',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textTertiary, letterSpacing: 1.2),
            ),
          ),
          ...sent.map((c) => _ChallengeTile(challenge: c, isReceived: false, onAccept: onAccept, onDecline: onDecline)),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ChallengeTile extends StatelessWidget {
  final Challenge challenge;
  final bool isReceived;
  final void Function(String) onAccept;
  final void Function(String) onDecline;

  const _ChallengeTile({
    required this.challenge,
    required this.isReceived,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final tag = isReceived
        ? (challenge.fromGamerTag ?? challenge.from.substring(0, 8))
        : (challenge.toGamerTag ?? challenge.to.substring(0, 8));
    final betLabel = challenge.bet > 0 ? '\$${challenge.bet.toStringAsFixed(0)}' : 'Free';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isReceived
              ? AppTheme.solanaPurple.withValues(alpha: 0.06)
              : AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: isReceived
                ? AppTheme.solanaPurple.withValues(alpha: 0.2)
                : AppTheme.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.sports_esports_rounded,
              size: 20,
              color: isReceived ? AppTheme.solanaPurple : AppTheme.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isReceived ? '$tag challenges you!' : 'Waiting for $tag...',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${challenge.duration} · $betLabel',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            if (isReceived) ...[
              ElevatedButton(
                onPressed: () => onAccept(challenge.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.solanaPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                  minimumSize: Size.zero,
                ),
                child: Text('Accept', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: AppTheme.textTertiary,
                tooltip: 'Decline',
                onPressed: () => onDecline(challenge.id),
              ),
            ] else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  'Pending',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.warning),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Badge Tab ────────────────────────────────────────────────────────────────

class _BadgeTab extends StatelessWidget {
  final String label;
  final int count;

  const _BadgeTab({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppTheme.error,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Quick Bet Button ─────────────────────────────────────────────────────────

class _QuickBetButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickBetButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}
