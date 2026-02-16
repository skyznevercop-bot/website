import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/escrow_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../models/trading_models.dart';
import '../providers/match_chat_provider.dart';
import '../providers/price_feed_provider.dart';
import '../providers/trading_provider.dart';
import '../widgets/match_chat_panel.dart';
import '../widgets/tradingview_chart_widget.dart';
import '../../wallet/providers/wallet_provider.dart';

// =============================================================================
// Shared helpers
// =============================================================================

String _fmtPrice(double price) {
  if (price >= 100) return price.toStringAsFixed(2);
  return price.toStringAsFixed(3);
}

String _fmtBalance(double value) {
  if (value >= 1000000) return '\$${(value / 1000000).toStringAsFixed(2)}M';
  if (value >= 1000) return '\$${(value / 1000).toStringAsFixed(1)}K';
  return '\$${value.toStringAsFixed(2)}';
}

Color _assetColor(String symbol) {
  switch (symbol) {
    case 'BTC':
      return const Color(0xFFF7931A);
    case 'ETH':
      return const Color(0xFF627EEA);
    case 'SOL':
      return AppTheme.solanaPurple;
    default:
      return AppTheme.textSecondary;
  }
}

Color _leverageColor(double lev, bool isLong) {
  if (lev >= 76) return AppTheme.error;
  if (lev >= 26) return AppTheme.warning;
  return isLong ? AppTheme.success : AppTheme.error;
}

// =============================================================================
// Arena Screen
// =============================================================================

class ArenaScreen extends ConsumerStatefulWidget {
  final int durationSeconds;
  final double betAmount;
  final String? matchId;
  final String? opponentAddress;
  final String? opponentGamerTag;
  final int? startTime;

  const ArenaScreen({
    super.key,
    required this.durationSeconds,
    required this.betAmount,
    this.matchId,
    this.opponentAddress,
    this.opponentGamerTag,
    this.startTime,
  });

  @override
  ConsumerState<ArenaScreen> createState() => _ArenaScreenState();
}

class _ArenaScreenState extends ConsumerState<ArenaScreen> {
  bool _chatOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      int remaining = widget.durationSeconds;
      if (widget.startTime != null) {
        final elapsed =
            (DateTime.now().millisecondsSinceEpoch - widget.startTime!) ~/ 1000;
        remaining =
            (widget.durationSeconds - elapsed).clamp(0, widget.durationSeconds);
      }

      final arenaUri = Uri(
        path: AppConstants.arenaRoute,
        queryParameters: {
          'd': widget.durationSeconds.toString(),
          'bet': widget.betAmount.toString(),
          if (widget.matchId != null) 'matchId': widget.matchId!,
          if (widget.opponentAddress != null) 'opp': widget.opponentAddress!,
          if (widget.opponentGamerTag != null)
            'oppTag': widget.opponentGamerTag!,
          if (widget.startTime != null) 'st': widget.startTime.toString(),
        },
      ).toString();

      ref.read(tradingProvider.notifier).startMatch(
            durationSeconds: remaining,
            betAmount: widget.betAmount,
            matchId: widget.matchId,
            opponentAddress: widget.opponentAddress,
            opponentGamerTag: widget.opponentGamerTag,
            arenaRoute: arenaUri,
          );

      // Initialize chat for this match.
      final wallet = ref.read(walletProvider);
      ref.read(matchChatProvider.notifier).init(
            matchId: widget.matchId ?? '',
            myAddress: wallet.address ?? '',
            myTag: wallet.gamerTag ?? 'You',
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tradingProvider);
    final isMobile = Responsive.isMobile(context);

    ref.listen<Map<String, double>>(priceFeedProvider, (_, prices) {
      ref.read(tradingProvider.notifier).updatePrices(prices);
    });

    final showOverlay = !state.matchActive && state.matchId != null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          Column(
            children: [
              _ArenaToolbar(
                state: state,
                chatOpen: _chatOpen,
                onChatToggle: () => setState(() => _chatOpen = !_chatOpen),
              ),
              Expanded(
                child: isMobile
                    ? _buildMobileLayout(state)
                    : _buildDesktopLayout(state),
              ),
            ],
          ),
          if (showOverlay)
            Positioned.fill(
              child: _MatchResultOverlay(state: state),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(TradingState state) {
    final orderW = Responsive.value<double>(context,
        mobile: 340, tablet: 300, desktop: 340);
    final chatW = Responsive.value<double>(context,
        mobile: 300, tablet: 260, desktop: 300);
    final positionsH = Responsive.value<double>(context,
        mobile: 180, tablet: 180, desktop: 200);

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _AssetMarketBar(state: state),
              Expanded(
                child: TradingViewChart(
                  tvSymbol: state.selectedAsset.tvSymbol,
                ),
              ),
              Container(height: 1, color: AppTheme.border),
              SizedBox(
                height: positionsH,
                child: _PositionsTable(state: state),
              ),
            ],
          ),
        ),
        Container(width: 1, color: AppTheme.border),
        SizedBox(
          width: orderW,
          child: _OrderPanel(state: state),
        ),
        if (_chatOpen) ...[
          Container(width: 1, color: AppTheme.border),
          SizedBox(
            width: chatW,
            child: MatchChatPanel(
              onClose: () => setState(() => _chatOpen = false),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMobileLayout(TradingState state) {
    return Column(
      children: [
        _AssetMarketBar(state: state),
        Expanded(
          flex: 5,
          child: TradingViewChart(tvSymbol: state.selectedAsset.tvSymbol),
        ),
        Container(height: 1, color: AppTheme.border),
        Expanded(
          flex: 7,
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                Container(
                  color: AppTheme.background,
                  child: TabBar(
                    labelColor: AppTheme.solanaPurple,
                    unselectedLabelColor: AppTheme.textTertiary,
                    indicatorColor: AppTheme.solanaPurple,
                    indicatorWeight: 2,
                    labelStyle: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    tabs: const [
                      Tab(text: 'Trade'),
                      Tab(text: 'Positions'),
                      Tab(text: 'Chat'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: _OrderPanel(state: state),
                      ),
                      _PositionsTable(state: state),
                      const MatchChatPanel(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Arena Toolbar — merged with opponent info
// =============================================================================

class _ArenaToolbar extends StatelessWidget {
  final TradingState state;
  final bool chatOpen;
  final VoidCallback onChatToggle;
  const _ArenaToolbar({
    required this.state,
    this.chatOpen = false,
    required this.onChatToggle,
  });

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _roi =>
      state.initialBalance > 0
          ? (state.equity - state.initialBalance) / state.initialBalance * 100
          : 0;

  @override
  Widget build(BuildContext context) {
    final pnl = state.totalUnrealizedPnl;
    final pnlColor = pnl >= 0 ? AppTheme.success : AppTheme.error;
    final isMobile = Responsive.isMobile(context);
    final oppRoi = state.opponentRoi;
    final oppRoiColor = oppRoi >= 0 ? AppTheme.success : AppTheme.error;

    return Container(
      height: 48,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          // Back button
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                if (state.matchActive) {
                  _showExitDialog(context);
                } else {
                  context.go(AppConstants.playRoute);
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_back_rounded,
                      size: 18, color: AppTheme.textSecondary),
                  if (!isMobile) ...[
                    const SizedBox(width: 8),
                    Text(
                      'SolFight',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          if (state.matchActive) ...[
            // Timer with glow
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: state.matchTimeRemainingSeconds <= 30
                    ? AppTheme.error.withValues(alpha: 0.15)
                    : AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(6),
                boxShadow: state.matchTimeRemainingSeconds <= 60
                    ? [
                        BoxShadow(
                          color: AppTheme.error.withValues(alpha: 0.25),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_rounded,
                      size: 14,
                      color: state.matchTimeRemainingSeconds <= 30
                          ? AppTheme.error
                          : AppTheme.textSecondary),
                  const SizedBox(width: 5),
                  Text(
                    _formatTime(state.matchTimeRemainingSeconds),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: state.matchTimeRemainingSeconds <= 30
                          ? AppTheme.error
                          : AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Opponent ROI badge
            if (state.opponentGamerTag != null) ...[
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isMobile) ...[
                        Flexible(
                          child: Text(
                            'VS ${state.opponentGamerTag}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (isMobile)
                        Text(
                          'VS ',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: oppRoiColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${oppRoi >= 0 ? '+' : ''}${oppRoi.toStringAsFixed(2)}%',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: oppRoiColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ],
          const Spacer(),
          if (!isMobile) ...[
            // Chat toggle button
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onChatToggle,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: chatOpen
                        ? AppTheme.solanaPurple.withValues(alpha: 0.15)
                        : AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    chatOpen
                        ? Icons.chat_bubble_rounded
                        : Icons.chat_bubble_outline_rounded,
                    size: 16,
                    color: chatOpen
                        ? AppTheme.solanaPurple
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _ToolbarStat(label: 'Balance', value: _fmtBalance(state.balance)),
            const SizedBox(width: 14),
          ],
          _ToolbarStat(label: 'Equity', value: _fmtBalance(state.equity)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: pnlColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${_roi >= 0 ? '+' : ''}${_roi.toStringAsFixed(2)}%',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: pnlColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => PointerInterceptor(
          child: AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
        title: Text('Leave Match?',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppTheme.textPrimary)),
        content: Text(
            'You can return to your match from the lobby, or forfeit to end it now.',
            style:
                GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Stay')),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.solanaPurple),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go(AppConstants.playRoute);
            },
            child: Text('Return to Lobby',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.solanaPurple)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () {
              Navigator.of(ctx).pop();
              // Disconnect WS so the backend sees it as a disconnect → forfeit.
              // The 30s grace period timer on the backend will then settle.
              ApiClient.instance.disconnectWebSocket();
              ProviderScope.containerOf(context)
                  .read(tradingProvider.notifier)
                  .endMatch(isForfeit: true);
              context.go(AppConstants.playRoute);
              // Reconnect WS after navigating away.
              Future.delayed(const Duration(seconds: 1), () {
                ApiClient.instance.connectWebSocket();
              });
            },
            child: const Text('Forfeit Match'),
          ),
        ],
      )),
    );
  }
}

class _ToolbarStat extends StatelessWidget {
  final String label;
  final String value;
  const _ToolbarStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label,
            style:
                GoogleFonts.inter(fontSize: 10, color: AppTheme.textTertiary)),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: AppTheme.textPrimary)),
      ],
    );
  }
}

// =============================================================================
// Asset Market Bar — price integrated into selected tab
// =============================================================================

class _AssetMarketBar extends ConsumerWidget {
  final TradingState state;
  const _AssetMarketBar({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = Responsive.isMobile(context);

    return Container(
      height: 42,
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Padding(
            padding: EdgeInsets.only(left: isMobile ? 8 : 12),
            child: Row(
              children: List.generate(TradingAsset.all.length, (index) {
                final asset = TradingAsset.all[index];
                final isSelected = index == state.selectedAssetIndex;
                final price =
                    state.currentPrices[asset.symbol] ?? asset.basePrice;
                final color = _assetColor(asset.symbol);

                return Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: GestureDetector(
                    onTap: () =>
                        ref.read(tradingProvider.notifier).selectAsset(index),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 10 : 14, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isSelected ? color : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  asset.symbol[0],
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: color,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              asset.symbol,
                              style: GoogleFonts.inter(
                                fontSize: isSelected ? 14 : 13,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppTheme.textPrimary
                                    : AppTheme.textSecondary,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              Text(
                                '\$${_fmtPrice(price)}',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Order Panel
// =============================================================================

class _OrderPanel extends ConsumerStatefulWidget {
  final TradingState state;
  const _OrderPanel({required this.state});

  @override
  ConsumerState<_OrderPanel> createState() => _OrderPanelState();
}

class _OrderPanelState extends ConsumerState<_OrderPanel>
    with SingleTickerProviderStateMixin {
  final _sizeCtrl = TextEditingController(text: '10000');
  final _slCtrl = TextEditingController();
  final _tpCtrl = TextEditingController();
  double _leverage = 10;
  bool _isLong = true;
  bool _showSlTp = false;
  bool _actionHovered = false;

  // Price flash animation
  late final AnimationController _priceFlashCtrl;
  double _lastPrice = 0;
  int _priceDirection = 0; // -1 down, 0 neutral, 1 up

  @override
  void initState() {
    super.initState();
    _priceFlashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void didUpdateWidget(covariant _OrderPanel old) {
    super.didUpdateWidget(old);
    final newPrice = widget.state.currentPrice;
    if (_lastPrice > 0 && newPrice != _lastPrice) {
      _priceDirection = newPrice > _lastPrice ? 1 : -1;
      _priceFlashCtrl.forward(from: 0);
    }
    _lastPrice = newPrice;
  }

  @override
  void dispose() {
    _priceFlashCtrl.dispose();
    _sizeCtrl.dispose();
    _slCtrl.dispose();
    _tpCtrl.dispose();
    super.dispose();
  }

  void _openPosition() {
    final size = double.tryParse(_sizeCtrl.text);
    if (size == null || size <= 0) return;
    if (size > widget.state.balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient balance',
              style: GoogleFonts.inter(fontSize: 13)),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        ),
      );
      return;
    }

    final sl = double.tryParse(_slCtrl.text);
    final tp = double.tryParse(_tpCtrl.text);

    ref.read(tradingProvider.notifier).openPosition(
          assetSymbol: widget.state.selectedAsset.symbol,
          isLong: _isLong,
          size: size,
          leverage: _leverage,
          stopLoss: sl,
          takeProfit: tp,
        );

    _slCtrl.clear();
    _tpCtrl.clear();
    setState(() => _showSlTp = false);
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.state.selectedAsset;
    final balance = widget.state.balance;
    final matchActive = widget.state.matchActive;
    final currentPrice = widget.state.currentPrice;

    final size = double.tryParse(_sizeCtrl.text) ?? 0;
    final notional = size * _leverage;
    final liqPrice = _isLong
        ? currentPrice * (1 - (1 / _leverage) * 0.9)
        : currentPrice * (1 + (1 / _leverage) * 0.9);

    final accentColor = _isLong ? AppTheme.success : AppTheme.error;
    final levColor = _leverageColor(_leverage, _isLong);

    return Container(
      color: AppTheme.surface,
      child: Column(
        children: [
          // Long/Short tabs
          Container(
            height: 48,
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _DirectionTab(
                    label: 'Long',
                    icon: Icons.trending_up_rounded,
                    isActive: _isLong,
                    color: AppTheme.success,
                    onTap: () => setState(() => _isLong = true),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _DirectionTab(
                    label: 'Short',
                    icon: Icons.trending_down_rounded,
                    isActive: !_isLong,
                    color: AppTheme.error,
                    onTap: () => setState(() => _isLong = false),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Market order label + live price
                  Row(
                    children: [
                      Text('MARKET ORDER',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textTertiary,
                            letterSpacing: 1,
                          )),
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppTheme.success,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.success.withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      AnimatedBuilder(
                        animation: _priceFlashCtrl,
                        builder: (context, _) {
                          final flashColor = _priceDirection == 1
                              ? AppTheme.success
                              : _priceDirection == -1
                                  ? AppTheme.error
                                  : AppTheme.textPrimary;
                          final color = Color.lerp(
                            flashColor,
                            AppTheme.textPrimary,
                            _priceFlashCtrl.value,
                          )!;
                          return Text(
                            '\$${_fmtPrice(currentPrice)}',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                              color: color,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // "You're paying" + available
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Size',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppTheme.textSecondary)),
                      Text('${_fmtBalance(balance)} available',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppTheme.textTertiary)),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Amount input
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2775CA).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '\$',
                                    style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF2775CA)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text('USDC',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _sizeCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.right,
                            style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              fillColor: Colors.transparent,
                              filled: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Percentage buttons
                  Row(
                    children: [
                      for (final pct in [25, 50, 75, 100]) ...[
                        if (pct != 25) const SizedBox(width: 6),
                        Expanded(
                          child: _PercentButton(
                            label: pct == 100 ? 'MAX' : '$pct%',
                            isActive: _isPctActive(pct, balance),
                            accentColor: accentColor,
                            onTap: matchActive
                                ? () {
                                    _sizeCtrl.text = (balance * pct / 100)
                                        .toStringAsFixed(0);
                                    setState(() {});
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Leverage
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Leverage',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppTheme.textSecondary)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: levColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_leverage.toStringAsFixed(_leverage == _leverage.roundToDouble() ? 0 : 1)}x',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: levColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: levColor,
                      inactiveTrackColor: AppTheme.border,
                      thumbColor: levColor,
                      overlayColor: levColor.withValues(alpha: 0.1),
                      trackHeight: 4,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 7),
                    ),
                    child: Slider(
                      value: _leverage.clamp(1, 100),
                      min: 1,
                      max: 100,
                      onChanged: matchActive
                          ? (v) => setState(() => _leverage =
                              double.parse(v.toStringAsFixed(0)))
                          : null,
                    ),
                  ),
                  // Leverage presets
                  Row(
                    children: [
                      for (final lev in [1, 5, 10, 25, 50, 100])
                        ...[
                          if (lev != 1) const SizedBox(width: 4),
                          Expanded(
                            child: _PercentButton(
                              label: '${lev}x',
                              isActive: _leverage == lev,
                              accentColor: _leverageColor(lev.toDouble(), _isLong),
                              onTap: matchActive
                                  ? () => setState(
                                      () => _leverage = lev.toDouble())
                                  : null,
                            ),
                          ),
                        ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // TP/SL toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Take Profit / Stop Loss',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppTheme.textSecondary)),
                      SizedBox(
                        height: 24,
                        width: 40,
                        child: FittedBox(
                          fit: BoxFit.fill,
                          child: Switch(
                            value: _showSlTp,
                            activeTrackColor: accentColor,
                            onChanged: (v) => setState(() => _showSlTp = v),
                          ),
                        ),
                      ),
                    ],
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: _buildSlTpInputs(currentPrice),
                    crossFadeState: _showSlTp
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 200),
                  ),
                  const SizedBox(height: 16),

                  // Action button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: MouseRegion(
                      cursor: matchActive
                          ? SystemMouseCursors.click
                          : SystemMouseCursors.basic,
                      onEnter: (_) => setState(() => _actionHovered = true),
                      onExit: (_) => setState(() => _actionHovered = false),
                      child: GestureDetector(
                        onTap: matchActive ? _openPosition : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeInOut,
                          decoration: BoxDecoration(
                            gradient: matchActive
                                ? (_isLong
                                    ? AppTheme.longGradient
                                    : AppTheme.shortGradient)
                                : null,
                            color: matchActive ? null : AppTheme.surfaceAlt,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                            boxShadow: matchActive && _actionHovered
                                ? [
                                    BoxShadow(
                                      color:
                                          accentColor.withValues(alpha: 0.3),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : matchActive
                                    ? [
                                        BoxShadow(
                                          color: accentColor
                                              .withValues(alpha: 0.2),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                          ),
                          child: Center(
                            child: Text(
                              _isLong
                                  ? 'Long ${asset.symbol}'
                                  : 'Short ${asset.symbol}',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: matchActive
                                    ? Colors.white
                                    : AppTheme.textTertiary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Info rows
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        _infoRow(
                            'Entry Price', '\$${_fmtPrice(currentPrice)}'),
                        const SizedBox(height: 8),
                        _infoRow('Liquidation Price',
                            '\$${_fmtPrice(liqPrice)}',
                            valueColor: AppTheme.error),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, color: AppTheme.border),
                        ),
                        _infoRow('Notional Size',
                            '\$${notional.toStringAsFixed(0)}'),
                      ],
                    ),
                  ),

                  if (!matchActive) ...[
                    const SizedBox(height: 16),
                    // Match result overlay handles end-of-match UI now.
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlTpInputs(double currentPrice) {
    final tpHint = _isLong
        ? (currentPrice * 1.02).toStringAsFixed(2)
        : (currentPrice * 0.98).toStringAsFixed(2);
    final slHint = _isLong
        ? (currentPrice * 0.98).toStringAsFixed(2)
        : (currentPrice * 1.02).toStringAsFixed(2);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TP Price',
                    style: GoogleFonts.inter(
                        fontSize: 10, color: AppTheme.success)),
                const SizedBox(height: 4),
                TextField(
                  controller: _tpCtrl,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.success),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    hintText: tpHint,
                    hintStyle: GoogleFonts.inter(
                        fontSize: 11, color: AppTheme.textTertiary),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SL Price',
                    style: GoogleFonts.inter(
                        fontSize: 10, color: AppTheme.error)),
                const SizedBox(height: 4),
                TextField(
                  controller: _slCtrl,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.error),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    hintText: slHint,
                    hintStyle: GoogleFonts.inter(
                        fontSize: 11, color: AppTheme.textTertiary),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isPctActive(int pct, double balance) {
    if (balance <= 0) return false;
    final currentSize = double.tryParse(_sizeCtrl.text) ?? 0;
    final target = balance * pct / 100;
    return (currentSize - target).abs() < 1;
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 12, color: AppTheme.textTertiary)),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: valueColor ?? AppTheme.textSecondary)),
      ],
    );
  }
}

// =============================================================================
// Reusable small widgets
// =============================================================================

class _DirectionTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;
  const _DirectionTab({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color:
                isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? Border.all(color: color.withValues(alpha: 0.3))
                : null,
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 16,
                    color: isActive ? color : AppTheme.textTertiary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isActive ? color : AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PercentButton extends StatefulWidget {
  final String label;
  final bool isActive;
  final Color accentColor;
  final VoidCallback? onTap;
  const _PercentButton({
    required this.label,
    required this.isActive,
    required this.accentColor,
    this.onTap,
  });

  @override
  State<_PercentButton> createState() => _PercentButtonState();
}

class _PercentButtonState extends State<_PercentButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeInOut,
          height: Responsive.value<double>(context,
              mobile: 38, desktop: 28),
          decoration: BoxDecoration(
            color: widget.isActive
                ? widget.accentColor.withValues(alpha: 0.12)
                : _hovered
                    ? AppTheme.surfaceAlt
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: widget.isActive
                  ? widget.accentColor.withValues(alpha: 0.3)
                  : AppTheme.border,
            ),
          ),
          child: Center(
            child: Text(
              widget.label,
              style: GoogleFonts.inter(
                fontSize: Responsive.value<double>(context,
                    mobile: 12, desktop: 11),
                fontWeight:
                    widget.isActive ? FontWeight.w700 : FontWeight.w500,
                color: widget.isActive
                    ? widget.accentColor
                    : AppTheme.textTertiary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Match Result Overlay — full-screen overlay shown when a match ends
// =============================================================================

class _MatchResultOverlay extends ConsumerStatefulWidget {
  final TradingState state;
  const _MatchResultOverlay({required this.state});

  @override
  ConsumerState<_MatchResultOverlay> createState() =>
      _MatchResultOverlayState();
}

class _MatchResultOverlayState extends ConsumerState<_MatchResultOverlay> {
  bool _visible = false;
  bool _claiming = false;
  String? _claimTx;
  String? _claimError;
  Timer? _pollTimer;
  int _pollCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
    // Poll the backend for the match result if we don't have it yet.
    if (!_hasResult) _startResultPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Poll the backend every 2s for the match result.
  /// This is far more reliable than depending solely on WebSocket messages.
  void _startResultPolling() {
    // Try immediately after a short delay (give WS a chance first).
    Future.delayed(const Duration(seconds: 2), () => _fetchResult());
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchResult();
    });
  }

  Future<void> _fetchResult() async {
    if (!mounted) return;
    if (_hasResult) {
      _pollTimer?.cancel();
      return;
    }

    _pollCount++;

    // Safety net: after ~30s of polling with no result, default to tie
    // so the overlay doesn't stay stuck forever.
    if (_pollCount > 10) {
      _pollTimer?.cancel();
      ref.read(tradingProvider.notifier).endMatch(isTie: true);
      return;
    }

    final matchId = widget.state.matchId;
    if (matchId == null) return;

    try {
      final data = await ApiClient.instance.get('/match/$matchId');
      if (!mounted || _hasResult) return;

      final status = data['status'] as String?;
      if (status == 'completed' || status == 'forfeited') {
        final winner = data['winner'] as String?;
        ref.read(tradingProvider.notifier).endMatch(
              winner: winner,
              isTie: false,
              isForfeit: status == 'forfeited',
            );
        _pollTimer?.cancel();
      } else if (status == 'tied') {
        ref.read(tradingProvider.notifier).endMatch(isTie: true);
        _pollTimer?.cancel();
      }
    } catch (_) {
      // API call failed — will retry on next poll.
    }
  }

  bool get _hasResult =>
      widget.state.matchWinner != null || widget.state.matchIsTie;

  bool get _isWinner {
    final wallet = ref.read(walletProvider);
    return widget.state.matchWinner != null &&
        widget.state.matchWinner == wallet.address;
  }

  bool get _isLoser {
    final wallet = ref.read(walletProvider);
    return widget.state.matchWinner != null &&
        widget.state.matchWinner != wallet.address;
  }

  double get _myRoi => widget.state.initialBalance > 0
      ? (widget.state.equity - widget.state.initialBalance) /
          widget.state.initialBalance *
          100
      : 0;

  Future<void> _claimPrize() async {
    final matchId = widget.state.matchId;
    if (matchId == null) return;

    setState(() {
      _claiming = true;
      _claimError = null;
    });

    try {
      final claimInfo =
          await ApiClient.instance.get('/match/$matchId/claim-info');

      final wallet = ref.read(walletProvider);
      final walletName = wallet.walletType?.name ?? 'phantom';

      final txSig = await EscrowService.claimWinnings(
        walletName: walletName,
        gamePda: claimInfo['gamePda'] as String,
        escrowTokenAccount: claimInfo['escrowTokenAccount'] as String,
        platformPda: claimInfo['platformPda'] as String,
        treasuryAddress: claimInfo['treasuryAddress'] as String,
      );

      if (mounted) setState(() => _claimTx = txSig);
    } catch (e) {
      if (mounted) {
        setState(() {
          _claimError = e.toString();
          _claiming = false; // Allow retry on error.
        });
      }
      return;
    }
    if (mounted) setState(() => _claiming = false);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 400),
      child: PointerInterceptor(
        child: Container(
          color: Colors.black.withValues(alpha: 0.8),
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 20 : 32),
              child:
                  _hasResult ? _buildResultCard(context) : _buildPendingCard(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppTheme.solanaPurple,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Determining Winner...',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Settling match on-chain',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(BuildContext context) {
    final isWinner = _isWinner;
    final isTie = widget.state.matchIsTie;
    final isLoser = _isLoser;
    final isForfeit = widget.state.matchIsForfeit;

    const gold = Color(0xFFFFD700);
    final resultColor = isTie
        ? AppTheme.textSecondary
        : isWinner
            ? gold
            : AppTheme.error;

    final resultText = isTie
        ? 'DRAW!'
        : isWinner
            ? 'YOU WON!'
            : 'YOU LOST';

    final subtitleText = isForfeit
        ? (isWinner ? 'Opponent forfeited' : 'You forfeited')
        : null;

    final myTag = ref.read(walletProvider).gamerTag ?? 'You';
    final oppTag = widget.state.opponentGamerTag ?? 'Opponent';
    final myRoi = _myRoi;
    final oppRoi = widget.state.opponentRoi;
    final myRoiColor = myRoi >= 0 ? AppTheme.success : AppTheme.error;
    final oppRoiColor = oppRoi >= 0 ? AppTheme.success : AppTheme.error;

    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: resultColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: resultColor.withValues(alpha: 0.12),
            blurRadius: 60,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Result icon
          Icon(
            isTie
                ? Icons.handshake_rounded
                : isWinner
                    ? Icons.emoji_events_rounded
                    : Icons.sentiment_dissatisfied_rounded,
            size: 56,
            color: resultColor,
          ),
          const SizedBox(height: 12),

          // Result headline
          Text(
            resultText,
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: resultColor,
              letterSpacing: 2,
            ),
          ),
          if (subtitleText != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitleText,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textTertiary,
              ),
            ),
          ],

          const SizedBox(height: 28),

          // ROI comparison
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // My stats
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'YOU',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textTertiary,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          myTag,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${myRoi >= 0 ? '+' : ''}${myRoi.toStringAsFixed(2)}%',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: myRoiColor,
                          ),
                        ),
                        if (isWinner) ...[
                          const SizedBox(height: 4),
                          const Icon(Icons.emoji_events_rounded,
                              size: 16, color: gold),
                        ],
                      ],
                    ),
                  ),
                  Container(width: 1, color: AppTheme.border),
                  // Opponent stats
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'OPP',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textTertiary,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          oppTag,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${oppRoi >= 0 ? '+' : ''}${oppRoi.toStringAsFixed(2)}%',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: oppRoiColor,
                          ),
                        ),
                        if (isLoser) ...[
                          const SizedBox(height: 4),
                          const Icon(Icons.emoji_events_rounded,
                              size: 16, color: gold),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Claim button (winner only, not yet claimed)
          if (isWinner && _claimTx == null) ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: MouseRegion(
                cursor: _claiming
                    ? SystemMouseCursors.basic
                    : SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _claiming ? null : _claimPrize,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: _claiming ? null : AppTheme.longGradient,
                      color: _claiming ? AppTheme.surfaceAlt : null,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _claiming
                          ? null
                          : [
                              BoxShadow(
                                color:
                                    AppTheme.success.withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Center(
                      child: _claiming
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.textSecondary,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                    Icons.account_balance_wallet_rounded,
                                    size: 18,
                                    color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  'Claim Prize',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Claim success
          if (_claimTx != null) ...[
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 18, color: AppTheme.success),
                  const SizedBox(width: 8),
                  Text(
                    'Prize Claimed Successfully!',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.success,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Claim error
          if (_claimError != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _claimError!,
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.error),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          // Tie refund
          if (isTie) ...[
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.textTertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Draw — deposits have been refunded on-chain.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Main action button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => context.go(AppConstants.playRoute),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.purpleGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color:
                            AppTheme.solanaPurple.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLoser
                              ? Icons.sports_esports_rounded
                              : Icons.home_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isLoser ? 'Find New Match' : 'Back to Lobby',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Positions Table
// =============================================================================

class _PositionsTable extends ConsumerStatefulWidget {
  final TradingState state;
  const _PositionsTable({required this.state});

  @override
  ConsumerState<_PositionsTable> createState() => _PositionsTableState();
}

class _PositionsTableState extends ConsumerState<_PositionsTable>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String? _hoveredRowId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final open = widget.state.openPositions;
    final closed = widget.state.closedPositions;

    return Container(
      color: AppTheme.background,
      child: Column(
        children: [
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                _posTab('Positions', 0, open.length),
                const SizedBox(width: 16),
                _posTab('History', 1, closed.length),
                const Spacer(),
                if (open.isNotEmpty)
                  Tooltip(
                    message: 'Close all open positions at market price',
                    child: GestureDetector(
                      onTap: () {
                        for (final p in open) {
                          ref
                              .read(tradingProvider.notifier)
                              .closePosition(p.id);
                        }
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                                color:
                                    AppTheme.error.withValues(alpha: 0.25)),
                          ),
                          child: Text('Close All',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.error)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                final isPositions = _tabController.index == 0;
                final items = isPositions ? open : closed;

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.show_chart_rounded,
                            size: 32, color: AppTheme.textTertiary),
                        const SizedBox(height: 8),
                        Text(
                            isPositions
                                ? 'No open positions'
                                : 'No trade history',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.textTertiary)),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    _tableHeader(isPositions),
                    Expanded(
                      child: ListView.builder(
                        itemCount: items.length,
                        padding: EdgeInsets.zero,
                        itemBuilder: (context, index) {
                          final pos = items[index];
                          final price = isPositions
                              ? (widget.state.currentPrices[pos.assetSymbol] ??
                                  pos.entryPrice)
                              : (pos.exitPrice ?? pos.entryPrice);
                          return _tableRow(pos, price, isPositions);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _posTab(String label, int index, int count) {
    final isActive = _tabController.index == index;
    return GestureDetector(
      onTap: () => setState(() => _tabController.animateTo(index)),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? AppTheme.solanaPurple : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color:
                      isActive ? AppTheme.textPrimary : AppTheme.textTertiary,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.solanaPurple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('$count',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.solanaPurple)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tableHeader(bool isPositions) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceAlt,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          _headerCell('MARKET', flex: 2),
          _headerCell('SIDE', flex: 1),
          _headerCell('SIZE', flex: 2),
          _headerCell('LEV', flex: 1),
          _headerCell('ENTRY', flex: 2),
          _headerCell(isPositions ? 'MARK' : 'EXIT', flex: 2),
          _headerCell('PNL', flex: 2),
          if (isPositions) _headerCell('', flex: 1),
          if (!isPositions) _headerCell('TYPE', flex: 1),
        ],
      ),
    );
  }

  Widget _headerCell(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: AppTheme.textTertiary)),
    );
  }

  Widget _tableRow(Position pos, double price, bool isPositions) {
    final pnl = pos.pnl(price);
    final pnlPct = pos.pnlPercent(price);
    final pnlColor = pnl >= 0 ? AppTheme.success : AppTheme.error;
    final sideColor = pos.isLong ? AppTheme.success : AppTheme.error;
    final isHovered = _hoveredRowId == pos.id;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredRowId = pos.id),
      onExit: (_) => setState(() => _hoveredRowId = null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isHovered
              ? AppTheme.surfaceAlt.withValues(alpha: 0.5)
              : Colors.transparent,
          border: const Border(
              bottom: BorderSide(color: AppTheme.border, width: 0.5)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: _assetColor(pos.assetSymbol)
                          .withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(pos.assetSymbol[0],
                          style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: _assetColor(pos.assetSymbol))),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(pos.assetSymbol,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary)),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: sideColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(pos.isLong ? 'Long' : 'Short',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: sideColor)),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text('\$${pos.size.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: AppTheme.textPrimary)),
            ),
            Expanded(
              flex: 1,
              child: Text(
                  '${pos.leverage.toStringAsFixed(pos.leverage == pos.leverage.roundToDouble() ? 0 : 1)}x',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary)),
            ),
            Expanded(
              flex: 2,
              child: Text('\$${_fmtPrice(pos.entryPrice)}',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: AppTheme.textPrimary)),
            ),
            Expanded(
              flex: 2,
              child: Text('\$${_fmtPrice(price)}',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: AppTheme.textPrimary)),
            ),
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${pnl >= 0 ? '+' : ''}\$${pnl.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: pnlColor),
                  ),
                  Text(
                    '${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(1)}%',
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: pnlColor),
                  ),
                ],
              ),
            ),
            if (isPositions)
              Expanded(
                flex: 1,
                child: Center(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => ref
                          .read(tradingProvider.notifier)
                          .closePosition(pos.id),
                      child: Tooltip(
                        message: 'Close at market',
                        child: Container(
                          width: Responsive.value<double>(context,
                              mobile: 36, desktop: 28),
                          height: Responsive.value<double>(context,
                              mobile: 36, desktop: 28),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color:
                                    AppTheme.error.withValues(alpha: 0.25)),
                          ),
                          child: const Icon(Icons.close_rounded,
                              size: 14, color: AppTheme.error),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (!isPositions)
              Expanded(
                flex: 1,
                child: _closeReasonBadge(pos.closeReason ?? 'manual'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _closeReasonBadge(String reason) {
    final labels = {
      'manual': 'Closed',
      'sl': 'SL',
      'tp': 'TP',
      'liquidation': 'Liqd',
      'match_end': 'End',
    };
    final colors = {
      'manual': AppTheme.textTertiary,
      'sl': AppTheme.error,
      'tp': AppTheme.success,
      'liquidation': AppTheme.error,
      'match_end': AppTheme.textTertiary,
    };
    final c = colors[reason] ?? AppTheme.textTertiary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        labels[reason] ?? reason,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
            fontSize: 9, fontWeight: FontWeight.w600, color: c),
      ),
    );
  }
}
