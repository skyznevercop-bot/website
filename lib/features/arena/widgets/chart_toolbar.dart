import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../providers/chart_settings_provider.dart';
import '../utils/arena_helpers.dart';

// =============================================================================
// Chart Toolbar — Timeframe selector + indicator toggles
// =============================================================================

class ChartToolbar extends ConsumerWidget {
  const ChartToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(chartSettingsProvider);
    final isMobile = Responsive.isMobile(context);

    return Container(
      height: 36,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: Row(
        children: [
          // ── Timeframe chips ──
          ...ChartInterval.values.map((tf) => Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _TimeframeChip(
              interval: tf,
              isSelected: settings.interval == tf,
              onTap: () =>
                  ref.read(chartSettingsProvider.notifier).setInterval(tf),
            ),
          )),

          const Spacer(),

          // ── Indicator toggles ──
          _IndicatorToggle(
            label: 'EMA',
            isActive: settings.indicators.ema,
            activeColor: const Color(0xFF26a69a),
            onTap: () =>
                ref.read(chartSettingsProvider.notifier).toggleEma(),
          ),
          const SizedBox(width: 4),
          _IndicatorToggle(
            label: 'BB',
            isActive: settings.indicators.bollingerBands,
            activeColor: const Color(0xFFFF9800),
            onTap: () =>
                ref.read(chartSettingsProvider.notifier).toggleBollingerBands(),
          ),
          const SizedBox(width: 4),
          _IndicatorToggle(
            label: 'RSI',
            isActive: settings.indicators.rsi,
            activeColor: AppTheme.solanaPurple,
            onTap: () =>
                ref.read(chartSettingsProvider.notifier).toggleRsi(),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Timeframe Chip — small selectable interval pill
// =============================================================================

class _TimeframeChip extends StatelessWidget {
  final ChartInterval interval;
  final bool isSelected;
  final VoidCallback onTap;

  const _TimeframeChip({
    required this.interval,
    required this.isSelected,
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.solanaPurple.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected
                  ? AppTheme.solanaPurple.withValues(alpha: 0.4)
                  : AppTheme.border.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Text(
            interval.label,
            style: interStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? AppTheme.solanaPurple
                  : AppTheme.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Indicator Toggle — small pill to enable/disable an indicator
// =============================================================================

class _IndicatorToggle extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _IndicatorToggle({
    required this.label,
    required this.isActive,
    required this.activeColor,
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive
                  ? activeColor.withValues(alpha: 0.4)
                  : AppTheme.border.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: interStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? activeColor : AppTheme.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}
