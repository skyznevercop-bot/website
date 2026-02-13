import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../models/trading_models.dart';
import '../providers/price_feed_provider.dart';
import '../providers/trading_provider.dart';
import '../widgets/tradingview_chart_widget.dart';

/// Full-screen trading arena with TradingView chart + custom demo trading panel.
class ArenaScreen extends ConsumerStatefulWidget {
  final int durationSeconds;
  final double betAmount;
  final String? matchId;
  final String? opponentAddress;
  final String? opponentGamerTag;

  const ArenaScreen({
    super.key,
    required this.durationSeconds,
    required this.betAmount,
    this.matchId,
    this.opponentAddress,
    this.opponentGamerTag,
  });

  @override
  ConsumerState<ArenaScreen> createState() => _ArenaScreenState();
}

class _ArenaScreenState extends ConsumerState<ArenaScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tradingProvider.notifier).startMatch(
            durationSeconds: widget.durationSeconds,
            betAmount: widget.betAmount,
            matchId: widget.matchId,
            opponentAddress: widget.opponentAddress,
            opponentGamerTag: widget.opponentGamerTag,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tradingProvider);
    final isMobile = Responsive.isMobile(context);

    // Sync prices from feed into trading provider
    ref.listen<Map<String, double>>(priceFeedProvider, (_, prices) {
      ref.read(tradingProvider.notifier).updatePrices(prices);
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          _ArenaToolbar(state: state),
          Expanded(
            child:
                isMobile ? _buildMobileLayout(state) : _buildDesktopLayout(state),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(TradingState state) {
    return Row(
      children: [
        // Left: asset tabs + TradingView chart
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _AssetTabBar(state: state),
              Expanded(
                child: TradingViewChart(
                  tvSymbol: state.selectedAsset.tvSymbol,
                ),
              ),
            ],
          ),
        ),
        Container(width: 1, color: AppTheme.border),
        // Right: order panel + positions
        SizedBox(
          width: 380,
          child: Column(
            children: [
              Expanded(flex: 3, child: _OrderPanel(state: state)),
              Container(height: 1, color: AppTheme.border),
              Expanded(flex: 2, child: _PositionsPanel(state: state)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(TradingState state) {
    return Column(
      children: [
        _AssetTabBar(state: state),
        Expanded(
          flex: 2,
          child: TradingViewChart(tvSymbol: state.selectedAsset.tvSymbol),
        ),
        Container(height: 1, color: AppTheme.border),
        Expanded(
          flex: 3,
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Container(
                  color: AppTheme.surface,
                  child: TabBar(
                    labelColor: AppTheme.solanaPurple,
                    unselectedLabelColor: AppTheme.textTertiary,
                    indicatorColor: AppTheme.solanaPurple,
                    labelStyle: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    tabs: const [
                      Tab(text: 'Trade'),
                      Tab(text: 'Positions'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(
                          child: _OrderPanel(state: state)),
                      _PositionsPanel(state: state),
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

// ═══════════════════════════════════════════════════════════════════════════════
// Arena Toolbar
// ═══════════════════════════════════════════════════════════════════════════════

class _ArenaToolbar extends StatelessWidget {
  final TradingState state;
  const _ArenaToolbar({required this.state});

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _fmtBalance(double value) {
    if (value >= 1000000) return '\$${(value / 1000000).toStringAsFixed(2)}M';
    if (value >= 1000) return '\$${(value / 1000).toStringAsFixed(1)}K';
    return '\$${value.toStringAsFixed(2)}';
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

    return Container(
      height: 52,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          // Back
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
                      size: 20, color: AppTheme.textSecondary),
                  if (!isMobile) ...[
                    const SizedBox(width: 8),
                    Text(
                      'SolFight Arena',
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
          const Spacer(),
          // Timer
          if (state.matchActive) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: state.matchTimeRemainingSeconds <= 30
                    ? AppTheme.error.withValues(alpha: 0.15)
                    : AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_rounded,
                      size: 16,
                      color: state.matchTimeRemainingSeconds <= 30
                          ? AppTheme.error
                          : AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    _formatTime(state.matchTimeRemainingSeconds),
                    style: GoogleFonts.inter(
                      fontSize: 14,
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
          ],
          // Demo Balance
          if (!isMobile) ...[
            _ToolbarStat(
                label: 'Demo Balance',
                value: _fmtBalance(state.balance)),
            const SizedBox(width: 12),
          ],
          _ToolbarStat(
              label: 'Equity',
              value: _fmtBalance(state.equity)),
          const SizedBox(width: 12),
          // ROI badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: pnlColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_roi >= 0 ? '+' : ''}${_roi.toStringAsFixed(2)}%',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
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
      builder: (ctx) => PointerInterceptor(child: AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
        title: Text('Leave Arena?',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppTheme.textPrimary)),
        content: Text(
            'All open positions will be closed and the match will end.',
            style:
                GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Stay')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () {
              Navigator.of(ctx).pop();
              ProviderScope.containerOf(context)
                  .read(tradingProvider.notifier)
                  .endMatch();
              context.go(AppConstants.playRoute);
            },
            child: const Text('Leave'),
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
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Asset Tab Bar
// ═══════════════════════════════════════════════════════════════════════════════

class _AssetTabBar extends ConsumerWidget {
  final TradingState state;
  const _AssetTabBar({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: TradingAsset.all.length,
        itemBuilder: (context, index) {
          final asset = TradingAsset.all[index];
          final isSelected = index == state.selectedAssetIndex;
          return GestureDetector(
            onTap: () =>
                ref.read(tradingProvider.notifier).selectAsset(index),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.solanaPurple.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected
                      ? Border.all(
                          color:
                              AppTheme.solanaPurple.withValues(alpha: 0.3))
                      : null,
                ),
                child: Center(
                  child: Text(
                    asset.symbol,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: isSelected
                          ? Colors.white
                          : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

}

// ═══════════════════════════════════════════════════════════════════════════════
// Order Panel — side, size, leverage, SL/TP, margin info
// ═══════════════════════════════════════════════════════════════════════════════

class _OrderPanel extends ConsumerStatefulWidget {
  final TradingState state;
  const _OrderPanel({required this.state});

  @override
  ConsumerState<_OrderPanel> createState() => _OrderPanelState();
}

class _OrderPanelState extends ConsumerState<_OrderPanel> {
  final _sizeCtrl = TextEditingController(text: '10000');
  final _slCtrl = TextEditingController();
  final _tpCtrl = TextEditingController();
  double _leverage = 5;

  @override
  void dispose() {
    _sizeCtrl.dispose();
    _slCtrl.dispose();
    _tpCtrl.dispose();
    super.dispose();
  }

  void _openPosition(bool isLong) {
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
          isLong: isLong,
          size: size,
          leverage: _leverage,
          stopLoss: sl,
          takeProfit: tp,
        );

    // Clear SL/TP after opening
    _slCtrl.clear();
    _tpCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.state.selectedAsset;
    final balance = widget.state.balance;
    final matchActive = widget.state.matchActive;
    final currentPrice = widget.state.currentPrice;

    // Calculate preview values
    final size = double.tryParse(_sizeCtrl.text) ?? 0;
    final margin = size;
    final notional = size * _leverage;
    final liqLong = currentPrice * (1 - (1 / _leverage) * 0.9);
    final liqShort = currentPrice * (1 + (1 / _leverage) * 0.9);

    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Scrollable form area
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header + current price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('OPEN POSITION',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textTertiary,
                              letterSpacing: 1.5)),
                      Text(
                        '${asset.symbol} ${_fmtPrice(currentPrice)}',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Size input
                  _buildLabel('Size (Margin)'),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _sizeCtrl,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      prefixText: '\$ ',
                      prefixStyle: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textTertiary),
                      suffixIcon: GestureDetector(
                        onTap: () {
                          _sizeCtrl.text = balance.toStringAsFixed(0);
                          setState(() {});
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Center(
                            widthFactor: 1,
                            child: Text('MAX',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.solanaPurple)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('Available: \$${balance.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppTheme.textTertiary)),
                  const SizedBox(height: 14),

                  // Leverage
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLabel('Leverage'),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: _leverage >= 20
                              ? AppTheme.warning.withValues(alpha: 0.15)
                              : AppTheme.solanaPurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_leverage.toStringAsFixed(0)}x',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _leverage >= 20
                                ? AppTheme.warning
                                : AppTheme.solanaPurple,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: _leverage >= 20
                          ? AppTheme.warning
                          : AppTheme.solanaPurple,
                      inactiveTrackColor: AppTheme.border,
                      thumbColor: _leverage >= 20
                          ? AppTheme.warning
                          : AppTheme.solanaPurple,
                      overlayColor:
                          AppTheme.solanaPurple.withValues(alpha: 0.1),
                      trackHeight: 4,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 8),
                    ),
                    child: Slider(
                      value: _leverage,
                      min: 1,
                      max: asset.maxLeverage,
                      divisions: (asset.maxLeverage - 1).toInt(),
                      onChanged: matchActive
                          ? (v) => setState(() => _leverage = v)
                          : null,
                    ),
                  ),
                  // Quick leverage buttons
                  Row(
                    children: [
                      for (final lev in [1, 2, 5, 10, 20, 50])
                        if (lev <= asset.maxLeverage)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: matchActive
                                  ? () => setState(
                                      () => _leverage = lev.toDouble())
                                  : null,
                              child: MouseRegion(
                                cursor: matchActive
                                    ? SystemMouseCursors.click
                                    : SystemMouseCursors.basic,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _leverage == lev
                                        ? AppTheme.solanaPurple
                                            .withValues(alpha: 0.1)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _leverage == lev
                                          ? AppTheme.solanaPurple
                                              .withValues(alpha: 0.3)
                                          : AppTheme.border,
                                    ),
                                  ),
                                  child: Text('${lev}x',
                                      style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: _leverage == lev
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: _leverage == lev
                                              ? AppTheme.solanaPurple
                                              : AppTheme.textTertiary)),
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                  if (_leverage >= 20) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 14, color: AppTheme.warning),
                        const SizedBox(width: 4),
                        Text('High leverage increases liquidation risk',
                            style: GoogleFonts.inter(
                                fontSize: 10, color: AppTheme.warning)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),

                  // SL / TP row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Stop Loss'),
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
                                hintText: 'Optional',
                                hintStyle: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppTheme.textTertiary),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Take Profit'),
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
                                hintText: 'Optional',
                                hintStyle: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppTheme.textTertiary),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Margin info box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAlt,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Column(
                      children: [
                        _infoRow('Margin Required',
                            '\$${margin.toStringAsFixed(2)}'),
                        const SizedBox(height: 4),
                        _infoRow('Notional Value',
                            '\$${notional.toStringAsFixed(2)}'),
                        const SizedBox(height: 4),
                        _infoRow('Liq. Price (Long)', _fmtPrice(liqLong),
                            color: AppTheme.error),
                        const SizedBox(height: 4),
                        _infoRow('Liq. Price (Short)', _fmtPrice(liqShort),
                            color: AppTheme.error),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Long / Short buttons (pinned at bottom)
          Row(
            children: [
              Expanded(
                child: _TradeButton(
                  label: 'Long',
                  icon: Icons.trending_up_rounded,
                  color: AppTheme.success,
                  enabled: matchActive,
                  onTap: () => _openPosition(true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TradeButton(
                  label: 'Short',
                  icon: Icons.trending_down_rounded,
                  color: AppTheme.error,
                  enabled: matchActive,
                  onTap: () => _openPosition(false),
                ),
              ),
            ],
          ),

          if (!matchActive) ...[
            const SizedBox(height: 12),
            _MatchEndBanner(state: widget.state),
          ],
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary));
  }

  Widget _infoRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11, color: AppTheme.textTertiary)),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color ?? AppTheme.textPrimary)),
      ],
    );
  }

  String _fmtPrice(double price) {
    if (price >= 10000) return price.toStringAsFixed(1);
    if (price >= 100) return price.toStringAsFixed(2);
    return price.toStringAsFixed(3);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Trade Button
// ═══════════════════════════════════════════════════════════════════════════════

class _TradeButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _TradeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_TradeButton> createState() => _TradeButtonState();
}

class _TradeButtonState extends State<_TradeButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.enabled ? widget.color : AppTheme.textTertiary;
    return MouseRegion(
      cursor:
          widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 48,
          decoration: BoxDecoration(
            color: _hovered && widget.enabled
                ? c.withValues(alpha: 0.2)
                : c.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: c.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 20, color: c),
              const SizedBox(width: 8),
              Text(widget.label,
                  style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w700, color: c)),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Match End Banner
// ═══════════════════════════════════════════════════════════════════════════════

class _MatchEndBanner extends StatelessWidget {
  final TradingState state;
  const _MatchEndBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    final isProfit = state.equity >= state.initialBalance;
    final c = isProfit ? AppTheme.success : AppTheme.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text('Match Over!',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text('Final equity: \$${state.equity.toStringAsFixed(2)}',
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600, color: c)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go(AppConstants.playRoute),
              child: const Text('Back to Lobby'),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Positions Panel
// ═══════════════════════════════════════════════════════════════════════════════

class _PositionsPanel extends ConsumerWidget {
  final TradingState state;
  const _PositionsPanel({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = state.openPositions;
    final closed = state.closedPositions;

    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('POSITIONS',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textTertiary,
                      letterSpacing: 1.5)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.solanaPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${open.length}',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.solanaPurple)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: open.isEmpty && closed.isEmpty
                ? Center(
                    child: Text('No positions yet',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: AppTheme.textTertiary)),
                  )
                : ListView(
                    children: [
                      for (final p in open)
                        _PositionRow(
                          position: p,
                          currentPrice:
                              state.currentPrices[p.assetSymbol] ??
                                  p.entryPrice,
                          onClose: () => ref
                              .read(tradingProvider.notifier)
                              .closePosition(p.id),
                        ),
                      if (closed.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text('CLOSED',
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textTertiary,
                                  letterSpacing: 1)),
                        ),
                        for (final p in closed.take(10))
                          _PositionRow(
                            position: p,
                            currentPrice: p.exitPrice ?? p.entryPrice,
                            onClose: null,
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _PositionRow extends StatelessWidget {
  final Position position;
  final double currentPrice;
  final VoidCallback? onClose;

  const _PositionRow({
    required this.position,
    required this.currentPrice,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final pnl = position.pnl(currentPrice);
    final pnlPct = position.pnlPercent(currentPrice);
    final pnlColor = pnl >= 0 ? AppTheme.success : AppTheme.error;
    final dirColor = position.isLong ? AppTheme.success : AppTheme.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: dirColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(position.isLong ? 'LONG' : 'SHORT',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: dirColor)),
              ),
              const SizedBox(width: 8),
              Text(position.assetSymbol,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              const SizedBox(width: 6),
              Text('${position.leverage.toStringAsFixed(0)}x',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppTheme.textTertiary)),
              const Spacer(),
              Text(
                '${pnl >= 0 ? '+' : ''}\$${pnl.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: pnlColor),
              ),
              const SizedBox(width: 6),
              Text(
                '${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(1)}%',
                style: GoogleFonts.inter(fontSize: 11, color: pnlColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Entry: ${_fmtPrice(position.entryPrice)}',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppTheme.textTertiary)),
              const SizedBox(width: 10),
              Text('Size: \$${position.size.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppTheme.textTertiary)),
              if (position.stopLoss != null) ...[
                const SizedBox(width: 10),
                Text('SL: ${_fmtPrice(position.stopLoss!)}',
                    style: GoogleFonts.inter(
                        fontSize: 10, color: AppTheme.error)),
              ],
              if (position.takeProfit != null) ...[
                const SizedBox(width: 10),
                Text('TP: ${_fmtPrice(position.takeProfit!)}',
                    style: GoogleFonts.inter(
                        fontSize: 10, color: AppTheme.success)),
              ],
              const Spacer(),
              if (onClose != null)
                GestureDetector(
                  onTap: onClose,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppTheme.error.withValues(alpha: 0.3)),
                      ),
                      child: Text('Close',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.error)),
                    ),
                  ),
                ),
              if (onClose == null && position.closeReason != null)
                _closeReasonBadge(position.closeReason!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _closeReasonBadge(String reason) {
    final labels = {
      'manual': 'Closed',
      'sl': 'Stop Loss',
      'tp': 'Take Profit',
      'liquidation': 'Liquidated',
      'match_end': 'Match End',
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        labels[reason] ?? reason,
        style: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w600, color: c),
      ),
    );
  }

  String _fmtPrice(double price) {
    if (price >= 10000) return price.toStringAsFixed(1);
    if (price >= 100) return price.toStringAsFixed(2);
    return price.toStringAsFixed(3);
  }
}
