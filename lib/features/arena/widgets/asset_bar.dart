import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../models/trading_models.dart';
import '../providers/trading_provider.dart';
import '../utils/arena_helpers.dart';

// =============================================================================
// Asset Bar — Compact asset pill selector with live prices & flash animation
// =============================================================================

class AssetBar extends ConsumerWidget {
  final TradingState state;

  const AssetBar({super.key, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = Responsive.isMobile(context);

    return Container(
      height: 42,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: Row(
        children: List.generate(TradingAsset.all.length, (index) {
          final asset = TradingAsset.all[index];
          return _AssetPill(
            asset: asset,
            price: state.currentPrices[asset.symbol] ?? asset.basePrice,
            isSelected: index == state.selectedAssetIndex,
            isMobile: isMobile,
            onTap: () =>
                ref.read(tradingProvider.notifier).selectAsset(index),
          );
        }),
      ),
    );
  }
}

// =============================================================================
// Asset Pill — Individual selectable asset with price flash
// =============================================================================

class _AssetPill extends StatefulWidget {
  final TradingAsset asset;
  final double price;
  final bool isSelected;
  final bool isMobile;
  final VoidCallback onTap;

  const _AssetPill({
    required this.asset,
    required this.price,
    required this.isSelected,
    required this.isMobile,
    required this.onTap,
  });

  @override
  State<_AssetPill> createState() => _AssetPillState();
}

class _AssetPillState extends State<_AssetPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _flashController;
  double _prevPrice = 0;
  Color _flashColor = Colors.transparent;

  @override
  void initState() {
    super.initState();
    _prevPrice = widget.price;
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void didUpdateWidget(_AssetPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.price != _prevPrice && _prevPrice > 0) {
      _flashColor = widget.price > _prevPrice
          ? AppTheme.success
          : AppTheme.error;
      _flashController.forward(from: 0);
      _prevPrice = widget.price;
    }
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = assetColor(widget.asset.symbol);
    final isUp = widget.price >= _prevPrice;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: widget.onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedBuilder(
            animation: _flashController,
            builder: (context, _) {
              final flashOpacity = (1.0 - _flashController.value) * 0.15;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(
                  horizontal: widget.isMobile ? 8 : 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? color.withValues(alpha: 0.08)
                      : flashOpacity > 0.01
                          ? _flashColor.withValues(alpha: flashOpacity)
                          : AppTheme.surfaceAlt.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.isSelected
                        ? color.withValues(alpha: 0.4)
                        : AppTheme.border.withValues(alpha: 0.3),
                    width: widget.isSelected ? 1.5 : 1,
                  ),
                  boxShadow: widget.isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.15),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Asset icon circle.
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          widget.asset.symbol[0],
                          style: interStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Symbol.
                    Text(
                      widget.asset.symbol,
                      style: interStyle(
                        fontSize: 12,
                        fontWeight: widget.isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: widget.isSelected
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                      ),
                    ),

                    // Price + direction indicator.
                    const SizedBox(width: 6),
                    Text(
                      '\$${fmtPrice(widget.price)}',
                      style: interStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: widget.isSelected
                            ? AppTheme.textPrimary
                            : AppTheme.textTertiary,
                        tabularFigures: true,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      isUp
                          ? Icons.arrow_drop_up_rounded
                          : Icons.arrow_drop_down_rounded,
                      size: 14,
                      color: isUp ? AppTheme.success : AppTheme.error,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
