import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide settings persisted via SharedPreferences.
class SettingsState {
  final bool soundEnabled;
  final double soundVolume;
  final bool screenShakeEnabled;

  const SettingsState({
    this.soundEnabled = true,
    this.soundVolume = 0.7,
    this.screenShakeEnabled = true,
  });

  SettingsState copyWith({
    bool? soundEnabled,
    double? soundVolume,
    bool? screenShakeEnabled,
  }) {
    return SettingsState(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      soundVolume: soundVolume ?? this.soundVolume,
      screenShakeEnabled: screenShakeEnabled ?? this.screenShakeEnabled,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  static const _soundEnabledKey = 'solfight_sound_enabled';
  static const _soundVolumeKey = 'solfight_sound_volume';
  static const _screenShakeKey = 'solfight_screen_shake_enabled';

  @override
  SettingsState build() {
    _load();
    return const SettingsState();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = SettingsState(
      soundEnabled: prefs.getBool(_soundEnabledKey) ?? true,
      soundVolume: prefs.getDouble(_soundVolumeKey) ?? 0.7,
      screenShakeEnabled: prefs.getBool(_screenShakeKey) ?? true,
    );
  }

  Future<void> setSoundEnabled(bool value) async {
    state = state.copyWith(soundEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledKey, value);
  }

  Future<void> setSoundVolume(double value) async {
    state = state.copyWith(soundVolume: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_soundVolumeKey, value);
  }

  Future<void> setScreenShakeEnabled(bool value) async {
    state = state.copyWith(screenShakeEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_screenShakeKey, value);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
