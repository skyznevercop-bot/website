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
  String? _editingPositionId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    final orders = widget.state.pendingOrders;
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
            ordersCount: orders.length,
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
                // Tab 2: Pending Orders.
                if (_tabController.index == 2) {
                  if (orders.isEmpty) {
                    return const _EmptyOrdersState();
                  }
                  return ListView.builder(
                    itemCount: orders.length,
                    padding: const EdgeInsets.all(8),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return _LimitOrderCard(
                        order: order,
                        onCancel: () => ref
                            .read(tradingProvider.notifier)
                            .cancelLimitOrder(order.id),
                      );
                    },
                  );
                }

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
                        isEditing: _editingPositionId == pos.id,
                        onEditToggle: isPositions
                            ? () => setState(() =>
                                _editingPositionId =
                                    _editingPositionId == pos.id
                                        ? null
                                        : pos.id)
                            : null,
                        onClose: () => ref
                            .read(tradingProvider.notifier)
                            .closePosition(pos.id),
                        onPartialClose: isPositions
                            ? () => ref
                                .read(tradingProvider.notifier)
                                .closePositionPartial(pos.id, 0.5)
                            : null,
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
                            isEditing: _editingPositionId == pos.id,
                            onHover: (h) => setState(
                                () => _hoveredRowId = h ? pos.id : null),
                            onEditToggle: isPositions
                                ? () => setState(() =>
                                    _editingPositionId =
                                        _editingPositionId == pos.id
                                            ? null
                                            : pos.id)
                                : null,
                            onClose: () => ref
                                .read(tradingProvider.notifier)
                                .closePosition(pos.id),
                            onPartialClose: () => ref
                                .read(tradingProvider.notifier)
                                .closePositionPartial(pos.id, 0.5),
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
  final int ordersCount;
  final double totalUnrealizedPnl;
  final VoidCallback? onCloseAll;

  const _TabHeader({
    required this.tabController,
    required this.openCount,
    required this.closedCount,
    this.ordersCount = 0,
    required this.totalUnrealizedPnl,
    this.onCloseAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: const Border(
            bottom: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: Row(
        children: [
          _PosTab(
              label: 'Positions',
              index: 0,
              count: openCount,
              controller: tabController),
          const SizedBox(width: 20),
          _PosTab(
              label: 'History',
              index: 1,
              count: closedCount,
              controller: tabController),
          const SizedBox(width: 20),
          _PosTab(
              label: 'Orders',
              index: 2,
              count: ordersCount,
              controller: tabController),

          // Unrealized PnL summary.
          if (openCount > 0) ...[
            const SizedBox(width: 14),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: pnlColor(totalUnrealizedPnl)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: pnlColor(totalUnrealizedPnl)
                      .withValues(alpha: 0.15),
                ),
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
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onCloseAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color:
                              AppTheme.error.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.close_rounded,
                            size: 12, color: AppTheme.error),
                        const SizedBox(width: 4),
                        Text('Close All',
                            style: interStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.error)),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 9),
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
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: interStyle(
                  fontSize: 12,
                  fontWeight:
                      isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? AppTheme.textPrimary
                      : AppTheme.textTertiary,
                ),
                child: Text(label),
              ),
              if (count > 0) ...[
                const SizedBox(width: 5),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppTheme.solanaPurple
                            .withValues(alpha: 0.15)
                        : AppTheme.textTertiary
                            .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$count',
                      style: interStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isActive
                              ? AppTheme.solanaPurple
                              : AppTheme.textTertiary)),
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
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt.withValues(alpha: 0.5),
        border: const Border(
            bottom: BorderSide(color: AppTheme.border, width: 0.5)),
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
          if (isPositions) _cell('', flex: 2),
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
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
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
  final bool isEditing;
  final ValueChanged<bool> onHover;
  final VoidCallback onClose;
  final VoidCallback? onPartialClose;
  final VoidCallback? onEditToggle;

  const _PositionRow({
    required this.position,
    required this.price,
    required this.isOpen,
    required this.isHovered,
    this.isEditing = false,
    required this.onHover,
    required this.onClose,
    this.onPartialClose,
    this.onEditToggle,
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        height: 44,
        decoration: BoxDecoration(
          color: isHovered
              ? AppTheme.surfaceAlt.withValues(alpha: 0.4)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isOpen ? pnlCol.withValues(alpha: 0.5) : Colors.transparent,
              width: 3,
            ),
            bottom:
                BorderSide(color: AppTheme.border.withValues(alpha: 0.4), width: 0.5),
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
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: sideColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      position.isLong ? 'Long' : 'Short',
                      style: interStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: sideColor),
                    ),
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

              // PnL + SL/TP badges.
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
                    if (isOpen &&
                        (position.stopLoss != null ||
                            position.takeProfit != null))
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            if (position.stopLoss != null)
                              _SlTpBadge(
                                label: 'SL',
                                value: position.stopLoss!,
                                color: AppTheme.error,
                              ),
                            if (position.stopLoss != null &&
                                position.takeProfit != null)
                              const SizedBox(width: 4),
                            if (position.takeProfit != null)
                              _SlTpBadge(
                                label: 'TP',
                                value: position.takeProfit!,
                                color: AppTheme.success,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Action.
              if (isOpen)
                Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Edit SL/TP button.
                      if (onEditToggle != null)
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: onEditToggle,
                            child: Tooltip(
                              message: 'Edit SL/TP',
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: isEditing
                                      ? AppTheme.solanaPurple
                                          .withValues(alpha: 0.15)
                                      : AppTheme.solanaPurple
                                          .withValues(alpha: 0.08),
                                  borderRadius:
                                      BorderRadius.circular(6),
                                  border: Border.all(
                                      color: AppTheme.solanaPurple
                                          .withValues(alpha: 0.25)),
                                ),
                                child: Icon(
                                    Icons.tune_rounded,
                                    size: 13,
                                    color: isEditing
                                        ? AppTheme.solanaPurple
                                        : AppTheme.textSecondary),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 3),
                      // 50% partial close button.
                      if (onPartialClose != null)
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: onPartialClose,
                            child: Tooltip(
                              message: 'Close 50%',
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: AppTheme.warning
                                      .withValues(alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(6),
                                  border: Border.all(
                                      color: AppTheme.warning
                                          .withValues(alpha: 0.25)),
                                ),
                                child: Center(
                                  child: Text('½',
                                      style: interStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.warning)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 3),
                      // Full close button.
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: onClose,
                          child: Tooltip(
                            message: 'Close at market',
                            child: AnimatedContainer(
                              duration:
                                  const Duration(milliseconds: 120),
                              width: 26,
                              height: 26,
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
                                  size: 13,
                                  color: AppTheme.error),
                            ),
                          ),
                        ),
                      ),
                    ],
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
    ),
      if (isEditing && isOpen)
        _SlTpEditor(position: position),
      ],
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
  final bool isEditing;
  final VoidCallback onClose;
  final VoidCallback? onPartialClose;
  final VoidCallback? onEditToggle;

  const _PositionCard({
    required this.position,
    required this.price,
    required this.isOpen,
    this.isEditing = false,
    required this.onClose,
    this.onPartialClose,
    this.onEditToggle,
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
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOpen
              ? pnlCol.withValues(alpha: 0.15)
              : AppTheme.border.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isOpen ? pnlCol.withValues(alpha: 0.6) : Colors.transparent,
                width: 3,
              ),
            ),
          ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Header: Asset + Side badge.
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: assetColor(position.assetSymbol)
                        .withValues(alpha: 0.12),
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
                const SizedBox(width: 8),
                Text(position.assetSymbol,
                    style: interStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: sideColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                        color: sideColor.withValues(alpha: 0.15)),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: pnlCol.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
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
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Body: Entry → Current price.
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Text('Entry',
                      style: interStyle(
                          fontSize: 9,
                          color: AppTheme.textTertiary)),
                  const SizedBox(width: 6),
                  Text('\$${fmtPrice(position.entryPrice)}',
                      style: interStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                          tabularFigures: true)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.trending_flat_rounded,
                        size: 14, color: AppTheme.textTertiary),
                  ),
                  Text(isOpen ? 'Mark' : 'Exit',
                      style: interStyle(
                          fontSize: 9,
                          color: AppTheme.textTertiary)),
                  const SizedBox(width: 6),
                  Text('\$${fmtPrice(price)}',
                      style: interStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          tabularFigures: true)),
                ],
              ),
            ),
            const SizedBox(height: 10),

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

                // Edit SL/TP button (open only).
                if (isOpen && onEditToggle != null) ...[
                  GestureDetector(
                    onTap: onEditToggle,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isEditing
                            ? AppTheme.solanaPurple.withValues(alpha: 0.15)
                            : AppTheme.solanaPurple.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppTheme.solanaPurple
                                .withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune_rounded,
                              size: 12,
                              color: isEditing
                                  ? AppTheme.solanaPurple
                                  : AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text('SL/TP',
                              style: interStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isEditing
                                      ? AppTheme.solanaPurple
                                      : AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                // Partial close button (open only).
                if (isOpen && onPartialClose != null) ...[
                  GestureDetector(
                    onTap: onPartialClose,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppTheme.warning
                                .withValues(alpha: 0.25)),
                      ),
                      child: Text('50%',
                          style: interStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.warning)),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

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

            // ── SL/TP Editor (expandable) ──
            if (isEditing && isOpen) ...[
              const SizedBox(height: 8),
              _SlTpEditor(position: position),
            ],
          ],
        ),
      ),
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
      'partial': '50%',
    };
    final colors = {
      'manual': AppTheme.textTertiary,
      'sl': AppTheme.error,
      'tp': AppTheme.success,
      'liquidation': AppTheme.error,
      'match_end': AppTheme.textTertiary,
      'partial': AppTheme.warning,
    };
    final c = colors[reason] ?? AppTheme.textTertiary;

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: c.withValues(alpha: 0.12)),
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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
                isPositions
                    ? Icons.show_chart_rounded
                    : Icons.history_rounded,
                size: 22,
                color: AppTheme.textTertiary),
          ),
          const SizedBox(height: 12),
          Text(
            isPositions ? 'No open positions' : 'No trade history',
            style: interStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary),
          ),
          if (isPositions) ...[
            const SizedBox(height: 4),
            Text(
              'Open a position to start trading',
              style: interStyle(
                  fontSize: 11, color: AppTheme.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// Empty Orders State
// =============================================================================

class _EmptyOrdersState extends StatelessWidget {
  const _EmptyOrdersState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.pending_actions_rounded,
                size: 22, color: AppTheme.textTertiary),
          ),
          const SizedBox(height: 12),
          Text('No pending orders',
              style: interStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text('Place a limit order to trigger at a target price',
              style: interStyle(
                  fontSize: 11, color: AppTheme.textTertiary)),
        ],
      ),
    );
  }
}

// =============================================================================
// Limit Order Card
// =============================================================================

class _LimitOrderCard extends StatelessWidget {
  final LimitOrder order;
  final VoidCallback onCancel;

  const _LimitOrderCard({
    required this.order,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final sideColor = order.isLong ? AppTheme.success : AppTheme.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.solanaPurple.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(
                color: AppTheme.solanaPurple,
                width: 3,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Header: Asset + Side + Limit price.
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: assetColor(order.assetSymbol)
                            .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(order.assetSymbol[0],
                            style: interStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: assetColor(order.assetSymbol))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(order.assetSymbol,
                        style: interStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: sideColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color: sideColor.withValues(alpha: 0.15)),
                      ),
                      child: Text(
                        order.isLong ? 'LONG' : 'SHORT',
                        style: interStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: sideColor),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.solanaPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color: AppTheme.solanaPurple
                                .withValues(alpha: 0.15)),
                      ),
                      child: Text(
                        'LIMIT',
                        style: interStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.solanaPurple),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceAlt.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('@ ',
                              style: interStyle(
                                  fontSize: 10,
                                  color: AppTheme.textTertiary)),
                          Text(
                            '\$${fmtPrice(order.limitPrice)}',
                            style: interStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                tabularFigures: true),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Footer: Size + Leverage + Cancel.
                Row(
                  children: [
                    Text(
                      '\$${order.size.toStringAsFixed(0)}',
                      style: interStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                          tabularFigures: true),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceAlt,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(fmtLeverage(order.leverage),
                          style: interStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary)),
                    ),
                    if (order.stopLoss != null) ...[
                      const SizedBox(width: 6),
                      _SlTpBadge(
                        label: 'SL',
                        value: order.stopLoss!,
                        color: AppTheme.error,
                      ),
                    ],
                    if (order.takeProfit != null) ...[
                      const SizedBox(width: 6),
                      _SlTpBadge(
                        label: 'TP',
                        value: order.takeProfit!,
                        color: AppTheme.success,
                      ),
                    ],
                    const Spacer(),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: onCancel,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color:
                                    AppTheme.error.withValues(alpha: 0.2)),
                          ),
                          child: Text('Cancel',
                              style: interStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.error)),
                        ),
                      ),
                    ),
                  ],
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
// SL/TP Badge — small inline indicator in PnL column
// =============================================================================

class _SlTpBadge extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _SlTpBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        '$label \$${fmtPrice(value)}',
        style: interStyle(
          fontSize: 8,
          fontWeight: FontWeight.w600,
          color: color,
          tabularFigures: true,
        ),
      ),
    );
  }
}

// =============================================================================
// SL/TP Editor — inline expandable editor for modifying SL/TP on open positions
// =============================================================================

class _SlTpEditor extends ConsumerStatefulWidget {
  final Position position;

  const _SlTpEditor({required this.position});

  @override
  ConsumerState<_SlTpEditor> createState() => _SlTpEditorState();
}

class _SlTpEditorState extends ConsumerState<_SlTpEditor> {
  late final TextEditingController _slController;
  late final TextEditingController _tpController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _slController = TextEditingController(
      text: widget.position.stopLoss != null
          ? fmtPrice(widget.position.stopLoss!)
          : '',
    );
    _tpController = TextEditingController(
      text: widget.position.takeProfit != null
          ? fmtPrice(widget.position.takeProfit!)
          : '',
    );
  }

  @override
  void dispose() {
    _slController.dispose();
    _tpController.dispose();
    super.dispose();
  }

  String? _validate() {
    final slText = _slController.text.trim();
    final tpText = _tpController.text.trim();
    final entry = widget.position.entryPrice;
    final isLong = widget.position.isLong;

    if (slText.isNotEmpty) {
      final sl = double.tryParse(slText);
      if (sl == null || sl <= 0) return 'Invalid SL price';
      if (isLong && sl >= entry) return 'SL must be below entry for longs';
      if (!isLong && sl <= entry) return 'SL must be above entry for shorts';
    }
    if (tpText.isNotEmpty) {
      final tp = double.tryParse(tpText);
      if (tp == null || tp <= 0) return 'Invalid TP price';
      if (isLong && tp <= entry) return 'TP must be above entry for longs';
      if (!isLong && tp >= entry) return 'TP must be below entry for shorts';
    }
    return null;
  }

  void _save() {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() => _error = null);

    final slText = _slController.text.trim();
    final tpText = _tpController.text.trim();
    final currentSl = widget.position.stopLoss;
    final currentTp = widget.position.takeProfit;

    final newSl = slText.isNotEmpty ? double.tryParse(slText) : null;
    final newTp = tpText.isNotEmpty ? double.tryParse(tpText) : null;
    final clearSl = slText.isEmpty && currentSl != null;
    final clearTp = tpText.isEmpty && currentTp != null;

    ref.read(tradingProvider.notifier).updatePositionSlTp(
          widget.position.id,
          stopLoss: newSl,
          takeProfit: newTp,
          clearSl: clearSl,
          clearTp: clearTp,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final entry = widget.position.entryPrice;
    final isLong = widget.position.isLong;

    // Smart hint prices: ~2% away from entry in the correct direction.
    final slHint = isLong
        ? fmtPrice(entry * 0.98)
        : fmtPrice(entry * 1.02);
    final tpHint = isLong
        ? fmtPrice(entry * 1.02)
        : fmtPrice(entry * 0.98);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isMobile ? 6 : 12,
        vertical: 6,
      ),
      padding: EdgeInsets.all(isMobile ? 10 : 14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _error != null
              ? AppTheme.error.withValues(alpha: 0.4)
              : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with entry price context.
          Row(
            children: [
              Icon(Icons.tune_rounded,
                  size: 13, color: AppTheme.textTertiary),
              const SizedBox(width: 6),
              Text('Risk Management',
                  style: interStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textTertiary,
                    letterSpacing: 0.8,
                  )),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Entry \$${fmtPrice(entry)}',
                  style: interStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                    tabularFigures: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // SL + TP fields side by side.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SlTpField(
                  label: 'Stop Loss',
                  shortLabel: 'SL',
                  color: AppTheme.error,
                  icon: Icons.shield_outlined,
                  controller: _slController,
                  hintText: slHint,
                  onClear: () {
                    _slController.clear();
                    setState(() => _error = null);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SlTpField(
                  label: 'Take Profit',
                  shortLabel: 'TP',
                  color: AppTheme.success,
                  icon: Icons.flag_outlined,
                  controller: _tpController,
                  hintText: tpHint,
                  onClear: () {
                    _tpController.clear();
                    setState(() => _error = null);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Error message + Save button row.
          Row(
            children: [
              if (_error != null)
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 12, color: AppTheme.error),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(_error!,
                            style: interStyle(
                                fontSize: 10, color: AppTheme.error)),
                      ),
                    ],
                  ),
                )
              else
                const Spacer(),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _save,
                  child: Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppTheme.solanaPurple,
                          Color(0xFF7C3AED),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.solanaPurple.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_rounded,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text('Save',
                            style: interStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SL/TP Field — individual input with label and clear button
// =============================================================================

class _SlTpField extends StatefulWidget {
  final String label;
  final String shortLabel;
  final Color color;
  final IconData icon;
  final TextEditingController controller;
  final String hintText;
  final VoidCallback onClear;

  const _SlTpField({
    required this.label,
    required this.shortLabel,
    required this.color,
    required this.icon,
    required this.controller,
    required this.hintText,
    required this.onClear,
  });

  @override
  State<_SlTpField> createState() => _SlTpFieldState();
}

class _SlTpFieldState extends State<_SlTpField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.controller.text.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: _focused
            ? widget.color.withValues(alpha: 0.04)
            : AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _focused
              ? widget.color.withValues(alpha: 0.5)
              : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label header.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 6, 8, 0),
            child: Row(
              children: [
                Icon(widget.icon,
                    size: 11,
                    color: _focused
                        ? widget.color
                        : AppTheme.textTertiary),
                const SizedBox(width: 4),
                Text(widget.label,
                    style: interStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: _focused
                          ? widget.color
                          : AppTheme.textTertiary,
                      letterSpacing: 0.3,
                    )),
                const Spacer(),
                if (hasValue)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        widget.onClear();
                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppTheme.textTertiary
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.close_rounded,
                            size: 10,
                            color: AppTheme.textTertiary),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Price input.
          SizedBox(
            height: 30,
            child: Focus(
              onFocusChange: (f) => setState(() => _focused = f),
              child: TextField(
                controller: widget.controller,
                onChanged: (_) => setState(() {}),
                style: interStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: hasValue
                      ? widget.color
                      : AppTheme.textPrimary,
                  tabularFigures: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: interStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textTertiary.withValues(alpha: 0.5),
                    tabularFigures: true,
                  ),
                  prefixText: '\$ ',
                  prefixStyle: interStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textTertiary,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  isDense: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
