import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds GlobalKeys for each onboarding target element.
class OnboardingTargetKeys {
  final GlobalKey heroKey;
  final GlobalKey timeframeWheelKey;
  final GlobalKey betAmountWheelKey;
  final GlobalKey matchInfoRowKey;
  final GlobalKey connectWalletButtonKey;

  const OnboardingTargetKeys({
    required this.heroKey,
    required this.timeframeWheelKey,
    required this.betAmountWheelKey,
    required this.matchInfoRowKey,
    required this.connectWalletButtonKey,
  });

  /// Returns the GlobalKey for a given step ID.
  GlobalKey keyForStepId(String stepId) {
    switch (stepId) {
      case 'hero':
        return heroKey;
      case 'timeframe':
        return timeframeWheelKey;
      case 'betAmount':
        return betAmountWheelKey;
      case 'matchInfo':
        return matchInfoRowKey;
      case 'connectWallet':
        return connectWalletButtonKey;
      default:
        return heroKey;
    }
  }
}

/// Provider to share GlobalKeys between _ArenaCard and the overlay.
class OnboardingKeysNotifier extends Notifier<OnboardingTargetKeys?> {
  @override
  OnboardingTargetKeys? build() => null;

  void setKeys(OnboardingTargetKeys keys) => state = keys;
  void clear() => state = null;
}

final onboardingKeysProvider =
    NotifierProvider<OnboardingKeysNotifier, OnboardingTargetKeys?>(
        OnboardingKeysNotifier.new);
