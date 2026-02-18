import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../models/trading_models.dart';
import '../providers/trading_provider.dart';
import '../utils/arena_helpers.dart';

// =============================================================================
// Positions Panel — "Active Ops" with PnL borders, liq dots, mobile cards
// =============================================================================

class PositionsPanel extends ConsumerStatefulWidget {
  final TradingState state;

  const PositionsPanel({super.key, required this.state});

  @override
  ConsumerState<PositionsPanel> createState() => _PositionsPanelState();
}

class _PositionsPanelState extends ConsumerState<PositionsPanel>
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
    final isMobile = Responsive.isMobile(context);

    return Container(
      color: AppTheme.background,
      child: Column(
        children: [
          // ── Tab bar with PnL summary ──
          _TabHeader(
            tabController: _tabController,
            openCount: open.length,
            closedCount: closed.length,
            totalUnrealizedPnl: widget.state.totalUnrealizedPnl,
            onCloseAll: open.isNotEmpty
                ? () {
                    for (final p in open) {
                      ref
                          .read(tradingProvider.notifier)
                          .closePosition(p.id);
                    }
                  }
                : null,
          ),

          // ── Position list ──
          Expanded(
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                final isPositions = _tabController.index == 0;
                final items = isPositions ? open : closed;

                if (items.isEmpty) {
                  return _EmptyState(isPositions: isPositions);
                }

                // Mobile: card layout.
                if (isMobile) {
                  return ListView.builder(
                    itemCount: items.length,
                    padding: const EdgeInsets.all(8),
                    itemBuilder: (context, index) {
                      final pos = items[index];
                      final price = isPositions
                          ? (widget.state.currentPrices[pos.assetSymbol] ??
                              pos.entryPrice)
                          : (pos.exitPrice ?? pos.entryPrice);
                      return _PositionCard(
                        position: pos,
                        price: price,
                        isOpen: isPositions,
                        onClose: () => ref
                            .read(tradingProvider.notifier)
                            .closePosition(pos.id),
                      );
                    },
                  );
                }

                // Desktop: table layout.
                return Column(
                  children: [
                    _TableHeader(isPositions: isPositions),
                    Expanded(
                      child: ListView.builder(
                        itemCount: items.length,
                        padding: EdgeInsets.zero,
                        itemBuilder: (context, index) {
                          final pos = items[index];
                          final price = isPositions
                              ? (widget.state
                                      .currentPrices[pos.assetSymbol] ??
                                  pos.entryPrice)
                              : (pos.exitPrice ?? pos.entryPrice);
                          return _PositionRow(
                            position: pos,
                            price: price,
                            isOpen: isPositions,
                            isHovered: _hoveredRowId == pos.id,
                            onHover: (h) => setState(
                                () => _hoveredRowId = h ? pos.id : null),
                            onClose: () => ref
                                .read(tradingProvider.notifier)
                                .closePosition(pos.id),
                          );
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
}

// =============================================================================
// Tab Header with PnL summary
// =============================================================================

class _TabHeader extends StatelessWidget {
  final TabController tabController;
  final int openCount;
  final int closedCount;
  final double totalUnrealizedPnl;
  final VoidCallback? onCloseAll;

  const _TabHeader({
    required this.tabController,
    required this.openCount,
    required this.closedCount,
    required this.totalUnrealizedPnl,
    this.onCloseAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          _PosTab(
              label: 'Positions',
              index: 0,
              count: openCount,
              controller: tabController),
          const SizedBox(width: 16),
          _PosTab(
              label: 'History',
              index: 1,
              count: closedCount,
              controller: tabController),

          // Unrealized PnL summary.
          if (openCount > 0) ...[
            const SizedBox(width: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: pnlColor(totalUnrealizedPnl)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                fmtPnl(totalUnrealizedPnl),
                style: interStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: pnlColor(totalUnrealizedPnl),
                  tabularFigures: true,
                ),
              ),
            ),
          ],

          const Spacer(),

          // Close all button with count badge.
          if (onCloseAll != null)
            Tooltip(
              message: 'Close all open positions at market price',
              child: GestureDetector(
                onTap: onCloseAll,
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Close All',
                            style: interStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.error)),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.error.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text('$openCount',
                              style: interStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.error)),
                        ),
                      ],
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

class _PosTab extends StatelessWidget {
  final String label;
  final int index;
  final int count;
  final TabController controller;

  const _PosTab({
    required this.label,
    required this.index,
    required this.count,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = controller.index == index;
    return GestureDetector(
      onTap: () => controller.animateTo(index),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive
                    ? AppTheme.solanaPurple
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(label,
                  style: interStyle(
                    fontSize: 12,
                    fontWeight:
                        isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive
                        ? AppTheme.textPrimary
                        : AppTheme.textTertiary,
                  )),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.solanaPurple
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('$count',
                      style: interStyle(
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
}

// =============================================================================
// Table Header (desktop)
// =============================================================================

class _TableHeader extends StatelessWidget {
  final bool isPositions;

  const _TableHeader({required this.isPositions});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceAlt,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          _cell('MARKET', flex: 2),
          _cell('SIDE', flex: 1),
          _cell('SIZE', flex: 2),
          _cell('LEV', flex: 1),
          _cell('ENTRY', flex: 2),
          _cell(isPositions ? 'MARK' : 'EXIT', flex: 2),
          _cell('PNL', flex: 2),
          if (isPositions) _cell('', flex: 1),
          if (!isPositions) _cell('TYPE', flex: 1),
        ],
      ),
    );
  }

  Widget _cell(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(label,
          style: interStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: AppTheme.textTertiary)),
    );
  }
}

// =============================================================================
// Position Row (desktop) — enhanced with PnL left border & liq dot
// =============================================================================

class _PositionRow extends StatelessWidget {
  final Position position;
  final double price;
  final bool isOpen;
  final bool isHovered;
  final ValueChanged<bool> onHover;
  final VoidCallback onClose;

  const _PositionRow({
    required this.position,
    required this.price,
    required this.isOpen,
    required this.isHovered,
    required this.onHover,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final pnl = position.pnl(price);
    final pnlPct = position.pnlPercent(price);
    final pnlCol = pnlColor(pnl);
    final sideColor = position.isLong ? AppTheme.success : AppTheme.error;

    // Liquidation proximity dot color.
    Color liqDotColor = AppTheme.success;
    if (isOpen) {
      final distToLiq = (price - position.liquidationPrice).abs();
      final totalRange =
          (position.entryPrice - position.liquidationPrice).abs();
      if (totalRange > 0) {
        final proximity = (distToLiq / totalRange).clamp(0.0, 1.0);
        liqDotColor = proximity > 0.5
            ? AppTheme.success
            : proximity > 0.25
                ? AppTheme.warning
                : AppTheme.error;
      }
    }

    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 42,
        decoration: BoxDecoration(
          color: isHovered
              ? AppTheme.surfaceAlt.withValues(alpha: 0.5)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isOpen ? pnlCol.withValues(alpha: 0.6) : Colors.transparent,
              width: 3,
            ),
            bottom:
                const BorderSide(color: AppTheme.border, width: 0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 13, right: 16),
          child: Row(
            children: [
              // Market.
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: assetColor(position.assetSymbol)
                            .withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(position.assetSymbol[0],
                            style: interStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: assetColor(
                                    position.assetSymbol))),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(position.assetSymbol,
                        style: interStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),

              // Side.
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: sideColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    position.isLong ? 'Long' : 'Short',
                    textAlign: TextAlign.center,
                    style: interStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: sideColor),
                  ),
                ),
              ),

              // Size.
              Expanded(
                flex: 2,
                child: Text(
                    '\$${position.size.toStringAsFixed(0)}',
                    style: interStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        tabularFigures: true)),
              ),

              // Leverage + liq dot.
              Expanded(
                flex: 1,
                child: Row(
                  children: [
                    if (isOpen) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: liqDotColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: liqDotColor
                                  .withValues(alpha: 0.4),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(fmtLeverage(position.leverage),
                        style: interStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary)),
                  ],
                ),
              ),

              // Entry.
              Expanded(
                flex: 2,
                child: Text(
                    '\$${fmtPrice(position.entryPrice)}',
                    style: interStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        tabularFigures: true)),
              ),

              // Mark / Exit.
              Expanded(
                flex: 2,
                child: Text('\$${fmtPrice(price)}',
                    style: interStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        tabularFigures: true)),
              ),

              // PnL.
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fmtPnl(pnl),
                        style: interStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: pnlCol,
                            tabularFigures: true)),
                    Text(fmtPercent(pnlPct),
                        style: interStyle(
                            fontSize: 9,
                            color: pnlCol,
                            tabularFigures: true)),
                  ],
                ),
              ),

              // Action.
              if (isOpen)
                Expanded(
                  flex: 1,
                  child: Center(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: onClose,
                        child: Tooltip(
                          message: 'Close at market',
                          child: AnimatedContainer(
                            duration:
                                const Duration(milliseconds: 120),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isHovered
                                  ? AppTheme.error
                                      .withValues(alpha: 0.2)
                                  : AppTheme.error
                                      .withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(6),
                              border: Border.all(
                                  color: AppTheme.error
                                      .withValues(alpha: 0.25)),
                              boxShadow: isHovered
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.error
                                            .withValues(alpha: 0.2),
                                        blurRadius: 6,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: const Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: AppTheme.error),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (!isOpen)
                Expanded(
                  flex: 1,
                  child: _CloseReasonBadge(
                      reason: position.closeReason ?? 'manual'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Position Card (mobile) — card-based layout
// =============================================================================

class _PositionCard extends StatelessWidget {
  final Position position;
  final double price;
  final bool isOpen;
  final VoidCallback onClose;

  const _PositionCard({
    required this.position,
    required this.price,
    required this.isOpen,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final pnl = position.pnl(price);
    final pnlPct = position.pnlPercent(price);
    final pnlCol = pnlColor(pnl);
    final sideColor = position.isLong ? AppTheme.success : AppTheme.error;

    // Liquidation proximity.
    Color liqDotColor = AppTheme.success;
    if (isOpen) {
      final distToLiq = (price - position.liquidationPrice).abs();
      final totalRange =
          (position.entryPrice - position.liquidationPrice).abs();
      if (totalRange > 0) {
        final proximity = (distToLiq / totalRange).clamp(0.0, 1.0);
        liqDotColor = proximity > 0.5
            ? AppTheme.success
            : proximity > 0.25
                ? AppTheme.warning
                : AppTheme.error;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isOpen ? pnlCol.withValues(alpha: 0.7) : AppTheme.border,
            width: 3,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            // Header: Asset + Side badge.
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: assetColor(position.assetSymbol)
                        .withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(position.assetSymbol[0],
                        style: interStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color:
                                assetColor(position.assetSymbol))),
                  ),
                ),
                const SizedBox(width: 6),
                Text(position.assetSymbol,
                    style: interStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: sideColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    position.isLong ? 'LONG' : 'SHORT',
                    style: interStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: sideColor),
                  ),
                ),
                const Spacer(),
                // PnL (large, colored).
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(fmtPnl(pnl),
                        style: interStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: pnlCol,
                            tabularFigures: true)),
                    Text(fmtPercent(pnlPct),
                        style: interStyle(
                            fontSize: 10,
                            color: pnlCol,
                            tabularFigures: true)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Body: Entry → Current price.
            Row(
              children: [
                Text('\$${fmtPrice(position.entryPrice)}',
                    style: interStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        tabularFigures: true)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 12, color: AppTheme.textTertiary),
                ),
                Text('\$${fmtPrice(price)}',
                    style: interStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        tabularFigures: true)),
              ],
            ),
            const SizedBox(height: 8),

            // Footer: Leverage + Liq + Close/Reason.
            Row(
              children: [
                // Leverage badge.
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(fmtLeverage(position.leverage),
                      style: interStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary)),
                ),
                const SizedBox(width: 6),

                // Liq proximity dot + distance.
                if (isOpen) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: liqDotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Liq \$${fmtPrice(position.liquidationPrice)}',
                    style: interStyle(
                        fontSize: 9,
                        color: AppTheme.textTertiary),
                  ),
                ],

                if (!isOpen)
                  _CloseReasonBadge(
                      reason: position.closeReason ?? 'manual'),

                const Spacer(),

                // Close button (open only).
                if (isOpen)
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppTheme.error
                                .withValues(alpha: 0.25)),
                      ),
                      child: Text('Close',
                          style: interStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.error)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Close Reason Badge
// =============================================================================

class _CloseReasonBadge extends StatelessWidget {
  final String reason;

  const _CloseReasonBadge({required this.reason});

  @override
  Widget build(BuildContext context) {
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
      padding:
          const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        labels[reason] ?? reason,
        textAlign: TextAlign.center,
        style: interStyle(
            fontSize: 9, fontWeight: FontWeight.w600, color: c),
      ),
    );
  }
}

// =============================================================================
// Empty State
// =============================================================================

class _EmptyState extends StatelessWidget {
  final bool isPositions;

  const _EmptyState({required this.isPositions});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
              isPositions
                  ? Icons.show_chart_rounded
                  : Icons.history_rounded,
              size: 32,
              color: AppTheme.textTertiary),
          const SizedBox(height: 8),
          Text(
            isPositions ? 'No open positions' : 'No trade history',
            style: interStyle(
                fontSize: 12, color: AppTheme.textTertiary),
          ),
          if (isPositions) ...[
            const SizedBox(height: 4),
            Text(
              'Use Quick Trade or the form above to open a position',
              style: interStyle(
                  fontSize: 10, color: AppTheme.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}
