import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Timeframe intervals available for the chart.
enum ChartInterval {
  m1(seconds: 60, label: '1m'),
  m5(seconds: 300, label: '5m'),
  m15(seconds: 900, label: '15m'),
  h1(seconds: 3600, label: '1h');

  final int seconds;
  final String label;
  const ChartInterval({required this.seconds, required this.label});
}

/// Which technical indicators are currently active.
class IndicatorState {
  final bool ema;
  final bool bollingerBands;
  final bool rsi;

  const IndicatorState({
    this.ema = false,
    this.bollingerBands = false,
    this.rsi = false,
  });

  IndicatorState copyWith({bool? ema, bool? bollingerBands, bool? rsi}) {
    return IndicatorState(
      ema: ema ?? this.ema,
      bollingerBands: bollingerBands ?? this.bollingerBands,
      rsi: rsi ?? this.rsi,
    );
  }
}

class ChartSettings {
  final ChartInterval interval;
  final IndicatorState indicators;

  const ChartSettings({
    this.interval = ChartInterval.m1,
    this.indicators = const IndicatorState(),
  });

  ChartSettings copyWith({
    ChartInterval? interval,
    IndicatorState? indicators,
  }) {
    return ChartSettings(
      interval: interval ?? this.interval,
      indicators: indicators ?? this.indicators,
    );
  }
}

class ChartSettingsNotifier extends Notifier<ChartSettings> {
  @override
  ChartSettings build() => const ChartSettings();

  void setInterval(ChartInterval interval) {
    state = state.copyWith(interval: interval);
  }

  void toggleEma() {
    state = state.copyWith(
      indicators: state.indicators.copyWith(ema: !state.indicators.ema),
    );
  }

  void toggleBollingerBands() {
    state = state.copyWith(
      indicators: state.indicators.copyWith(
        bollingerBands: !state.indicators.bollingerBands,
      ),
    );
  }

  void toggleRsi() {
    state = state.copyWith(
      indicators: state.indicators.copyWith(rsi: !state.indicators.rsi),
    );
  }
}

final chartSettingsProvider =
    NotifierProvider<ChartSettingsNotifier, ChartSettings>(
        ChartSettingsNotifier.new);
