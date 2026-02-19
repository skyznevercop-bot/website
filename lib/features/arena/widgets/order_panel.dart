import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/audio_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../providers/trading_provider.dart';
import '../utils/arena_helpers.dart';

// =============================================================================
// Order Panel — "Arsenal" with risk indicator and presets
// =============================================================================

class OrderPanel extends ConsumerStatefulWidget {
  final TradingState state;

  const OrderPanel({super.key, required this.state});

  @override
  ConsumerState<OrderPanel> createState() => _OrderPanelState();
}

class _OrderPanelState extends ConsumerState<OrderPanel>
    with SingleTickerProviderStateMixin {
  final _sizeCtrl = TextEditingController(text: '10000');
  final _slCtrl = TextEditingController();
  final _tpCtrl = TextEditingController();
  final _limitPriceCtrl = TextEditingController();
  double _leverage = 10;
  bool _isLong = true;
  bool _showSlTp = false;
  bool _actionHovered = false;
  bool _isLimitOrder = false;
  bool _trailingSl = false;

  // Price flash animation.
  late final AnimationController _priceFlashCtrl;
  double _lastPrice = 0;
  int _priceDirection = 0;

  @override
  void initState() {
    super.initState();
    _priceFlashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void didUpdateWidget(covariant OrderPanel old) {
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
    _limitPriceCtrl.dispose();
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

    // Extreme leverage confirmation (>= 50x).
    if (_leverage >= 50) {
      _showLeverageConfirmation(size);
      return;
    }

    _executeOrder(size);
  }

  void _showLeverageConfirmation(double size) {
    final currentPrice = widget.state.currentPrice;
    final liqPrice = _isLong
        ? currentPrice * (1 - (1 / _leverage) * 0.9)
        : currentPrice * (1 + (1 / _leverage) * 0.9);
    final liqDist = ((currentPrice - liqPrice).abs() / currentPrice * 100);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppTheme.warning, size: 22),
            const SizedBox(width: 8),
            Text('Extreme Leverage',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppTheme.textPrimary)),
          ],
        ),
        content: Text(
          'You\'re about to open a ${_isLong ? "LONG" : "SHORT"} position at ${_leverage.toStringAsFixed(0)}x leverage. '
          'Liquidation is only ${liqDist.toStringAsFixed(1)}% away from entry.',
          style: GoogleFonts.inter(
              fontSize: 14, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error),
            onPressed: () {
              Navigator.of(ctx).pop();
              _executeOrder(size);
            },
            child: Text('Confirm ${_leverage.toStringAsFixed(0)}x',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _executeOrder(double size) {
    final sl = double.tryParse(_slCtrl.text);
    final tp = double.tryParse(_tpCtrl.text);
    final trailingDist = _trailingSl ? sl : null;
    final effectiveSl = _trailingSl ? null : sl;

    AudioService.instance.playTradeOpen();

    if (_isLimitOrder) {
      final limitPrice = double.tryParse(_limitPriceCtrl.text);
      if (limitPrice == null || limitPrice <= 0) return;

      ref.read(tradingProvider.notifier).placeLimitOrder(
            assetSymbol: widget.state.selectedAsset.symbol,
            isLong: _isLong,
            limitPrice: limitPrice,
            size: size,
            leverage: _leverage,
            stopLoss: effectiveSl,
            takeProfit: tp,
            trailingStopDistance: trailingDist,
          );
    } else {
      ref.read(tradingProvider.notifier).openPosition(
            assetSymbol: widget.state.selectedAsset.symbol,
            isLong: _isLong,
            size: size,
            leverage: _leverage,
            stopLoss: effectiveSl,
            takeProfit: tp,
            trailingStopDistance: trailingDist,
          );
    }

    _slCtrl.clear();
    _tpCtrl.clear();
    _limitPriceCtrl.clear();
    setState(() {
      _showSlTp = false;
      _trailingSl = false;
    });
  }

  bool _isPctActive(int pct, double balance) {
    if (balance <= 0) return false;
    final currentSize = double.tryParse(_sizeCtrl.text) ?? 0;
    final target = balance * pct / 100;
    return (currentSize - target).abs() < 1;
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
    final levColor = leverageColor(_leverage, _isLong);
    final risk = riskFromLeverage(_leverage);

    return Container(
      color: AppTheme.surface,
      child: Column(
        children: [
          // ── Long / Short tabs ──
          _DirectionTabs(
            isLong: _isLong,
            onLong: () => setState(() => _isLong = true),
            onShort: () => setState(() => _isLong = false),
          ),

          // ── Scrollable order form ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Order type toggle + live price ──
                  Row(
                    children: [
                      // Market / Limit toggle.
                      Container(
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceAlt,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _OrderTypeTab(
                              label: 'MARKET',
                              isActive: !_isLimitOrder,
                              onTap: () =>
                                  setState(() => _isLimitOrder = false),
                            ),
                            _OrderTypeTab(
                              label: 'LIMIT',
                              isActive: _isLimitOrder,
                              onTap: () =>
                                  setState(() => _isLimitOrder = true),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Animated price flash or limit price input.
                      if (!_isLimitOrder)
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
                              '\$${fmtPrice(currentPrice)}',
                              style: interStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: color,
                                tabularFigures: true,
                              ),
                            );
                          },
                        )
                      else
                        SizedBox(
                          width: 140,
                          child: TextField(
                            controller: _limitPriceCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.right,
                            style: interStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.solanaPurple,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                            decoration: InputDecoration(
                              hintText: fmtPrice(currentPrice),
                              hintStyle: interStyle(
                                  fontSize: 18,
                                  color: AppTheme.textTertiary),
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                              isDense: true,
                              prefixText: '\$',
                              prefixStyle: interStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.solanaPurple,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Size input ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Size',
                          style: interStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary)),
                      Text('${fmtBalance(balance)} available',
                          style: interStyle(
                              fontSize: 11,
                              color: AppTheme.textTertiary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _SizeInput(
                      controller: _sizeCtrl,
                      onChanged: () => setState(() {})),
                  const SizedBox(height: 8),

                  // ── Size presets ──
                  Row(
                    children: [
                      for (final pct in [25, 50, 75, 100]) ...[
                        if (pct != 25) const SizedBox(width: 6),
                        Expanded(
                          child: _PresetButton(
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
                  const SizedBox(height: 16),

                  // ── Leverage with risk indicator ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text('Leverage',
                              style: interStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  riskColor(risk).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color:
                                    riskColor(risk).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              riskLabel(risk),
                              style: interStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: riskColor(risk),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: levColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          fmtLeverage(_leverage),
                          style: interStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: levColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // ── Leverage slider ──
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: levColor,
                      inactiveTrackColor: AppTheme.border,
                      thumbColor: levColor,
                      overlayColor: levColor.withValues(alpha: 0.1),
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7),
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

                  // ── Leverage presets ──
                  Row(
                    children: [
                      for (final lev in [1, 5, 10, 25, 50, 100]) ...[
                        if (lev != 1) const SizedBox(width: 4),
                        Expanded(
                          child: _PresetButton(
                            label: '${lev}x',
                            isActive: _leverage == lev,
                            accentColor:
                                leverageColor(lev.toDouble(), _isLong),
                            onTap: matchActive
                                ? () => setState(
                                    () => _leverage = lev.toDouble())
                                : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── TP/SL toggle ──
                  Row(
                    children: [
                      Text('Take Profit / Stop Loss',
                          style: interStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary)),
                      const Spacer(),
                      if (_showSlTp)
                        GestureDetector(
                          onTap: () =>
                              setState(() => _trailingSl = !_trailingSl),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: _trailingSl
                                    ? AppTheme.solanaPurple
                                        .withValues(alpha: 0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: _trailingSl
                                      ? AppTheme.solanaPurple
                                          .withValues(alpha: 0.3)
                                      : AppTheme.border,
                                ),
                              ),
                              child: Text(
                                'Trailing',
                                style: interStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _trailingSl
                                      ? AppTheme.solanaPurple
                                      : AppTheme.textTertiary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      SizedBox(
                        height: 24,
                        width: 40,
                        child: FittedBox(
                          fit: BoxFit.fill,
                          child: Switch(
                            value: _showSlTp,
                            activeTrackColor: accentColor,
                            onChanged: (v) =>
                                setState(() => _showSlTp = v),
                          ),
                        ),
                      ),
                    ],
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: _SlTpInputs(
                      slCtrl: _slCtrl,
                      tpCtrl: _tpCtrl,
                      isLong: _isLong,
                      currentPrice: currentPrice,
                      isTrailing: _trailingSl,
                    ),
                    crossFadeState: _showSlTp
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 200),
                  ),
                  const SizedBox(height: 14),

                  // ── Execute button (enhanced) ──
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: MouseRegion(
                      cursor: matchActive
                          ? SystemMouseCursors.click
                          : SystemMouseCursors.basic,
                      onEnter: (_) =>
                          setState(() => _actionHovered = true),
                      onExit: (_) =>
                          setState(() => _actionHovered = false),
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
                            color: matchActive
                                ? null
                                : AppTheme.surfaceAlt,
                            borderRadius: BorderRadius.circular(
                                AppTheme.radiusMd),
                            boxShadow: matchActive && _actionHovered
                                ? [
                                    BoxShadow(
                                      color: accentColor
                                          .withValues(alpha: 0.3),
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isLong
                                      ? Icons.trending_up_rounded
                                      : Icons.trending_down_rounded,
                                  size: 18,
                                  color: matchActive
                                      ? Colors.white
                                      : AppTheme.textTertiary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_isLimitOrder ? "LIMIT " : ""}${_isLong ? "LONG" : "SHORT"} ${asset.symbol} @ ${fmtLeverage(_leverage)}',
                                  style: interStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: matchActive
                                        ? Colors.white
                                        : AppTheme.textTertiary,
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

                  // ── Order info card ──
                  _OrderInfoCard(
                    currentPrice: currentPrice,
                    liqPrice: liqPrice,
                    notional: notional,
                    leverage: _leverage,
                    size: size,
                    isLong: _isLong,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Direction Tabs (Long / Short)
// =============================================================================

class _DirectionTabs extends StatelessWidget {
  final bool isLong;
  final VoidCallback onLong;
  final VoidCallback onShort;

  const _DirectionTabs({
    required this.isLong,
    required this.onLong,
    required this.onShort,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            isActive: isLong,
            color: AppTheme.success,
            onTap: onLong,
          )),
          const SizedBox(width: 4),
          Expanded(
              child: _DirectionTab(
            label: 'Short',
            icon: Icons.trending_down_rounded,
            isActive: !isLong,
            color: AppTheme.error,
            onTap: onShort,
          )),
        ],
      ),
    );
  }
}

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
            color: isActive
                ? color.withValues(alpha: 0.15)
                : Colors.transparent,
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
                  style: interStyle(
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

// =============================================================================
// Size Input
// =============================================================================

class _SizeInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _SizeInput({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    color:
                        const Color(0xFF2775CA).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '\$',
                      style: interStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF2775CA),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text('USDC',
                    style: interStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              style: interStyle(
                  fontSize: 20, fontWeight: FontWeight.w600),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d+\.?\d{0,2}')),
              ],
              onChanged: (_) => onChanged(),
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
    );
  }
}

// =============================================================================
// Preset Button
// =============================================================================

class _PresetButton extends StatefulWidget {
  final String label;
  final bool isActive;
  final Color accentColor;
  final VoidCallback? onTap;

  const _PresetButton({
    required this.label,
    required this.isActive,
    required this.accentColor,
    this.onTap,
  });

  @override
  State<_PresetButton> createState() => _PresetButtonState();
}

class _PresetButtonState extends State<_PresetButton> {
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
              style: interStyle(
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
// SL/TP Inputs
// =============================================================================

class _SlTpInputs extends StatelessWidget {
  final TextEditingController slCtrl;
  final TextEditingController tpCtrl;
  final bool isLong;
  final double currentPrice;
  final bool isTrailing;

  const _SlTpInputs({
    required this.slCtrl,
    required this.tpCtrl,
    required this.isLong,
    required this.currentPrice,
    this.isTrailing = false,
  });

  @override
  Widget build(BuildContext context) {
    final tpHint = isLong
        ? (currentPrice * 1.02).toStringAsFixed(2)
        : (currentPrice * 0.98).toStringAsFixed(2);
    final slHint = isTrailing
        ? (currentPrice * 0.02).toStringAsFixed(2)
        : isLong
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
                    style: interStyle(
                        fontSize: 10, color: AppTheme.success)),
                const SizedBox(height: 4),
                TextField(
                  controller: tpCtrl,
                  keyboardType: TextInputType.number,
                  style: interStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.success),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    hintText: tpHint,
                    hintStyle: interStyle(
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
                Text(isTrailing ? 'Trail Dist' : 'SL Price',
                    style: interStyle(
                        fontSize: 10,
                        color: isTrailing
                            ? AppTheme.solanaPurple
                            : AppTheme.error)),
                const SizedBox(height: 4),
                TextField(
                  controller: slCtrl,
                  keyboardType: TextInputType.number,
                  style: interStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.error),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    hintText: slHint,
                    hintStyle: interStyle(
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
}

// =============================================================================
// Order Type Tab (Market / Limit)
// =============================================================================

class _OrderTypeTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _OrderTypeTab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.solanaPurple.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            label,
            style: interStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isActive
                  ? AppTheme.solanaPurple
                  : AppTheme.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Order Info Card
// =============================================================================

class _OrderInfoCard extends StatelessWidget {
  final double currentPrice;
  final double liqPrice;
  final double notional;
  final double leverage;
  final double size;
  final bool isLong;

  const _OrderInfoCard({
    required this.currentPrice,
    required this.liqPrice,
    required this.notional,
    required this.leverage,
    required this.size,
    required this.isLong,
  });

  @override
  Widget build(BuildContext context) {
    final liqDist = currentPrice > 0
        ? ((currentPrice - liqPrice).abs() / currentPrice * 100)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _infoRow('Entry Price', '\$${fmtPrice(currentPrice)}'),
          const SizedBox(height: 8),
          _infoRow(
            'Liquidation',
            '\$${fmtPrice(liqPrice)}',
            valueColor: AppTheme.error,
          ),
          const SizedBox(height: 6),
          // Liquidation distance bar.
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (1.0 - liqDist / 100).clamp(0.0, 1.0),
                    minHeight: 3,
                    backgroundColor: AppTheme.border,
                    color: liqDist < 2
                        ? AppTheme.error
                        : liqDist < 5
                            ? AppTheme.warning
                            : AppTheme.success,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${liqDist.toStringAsFixed(1)}% away',
                style: interStyle(
                  fontSize: 9,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: AppTheme.border),
          ),
          _infoRow('Notional Size',
              '\$${notional.toStringAsFixed(0)}'),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: interStyle(
                fontSize: 12, color: AppTheme.textTertiary)),
        Text(value,
            style: interStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppTheme.textSecondary,
                tabularFigures: true)),
      ],
    );
  }
}
