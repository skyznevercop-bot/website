import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/onboarding_state.dart';

const _kOnboardingCompleteKey = 'solfight_onboarding_complete';

class OnboardingNotifier extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => const OnboardingState();

  /// Called on first app load. Checks shared_preferences,
  /// and if this is the first visit, activates onboarding.
  Future<void> maybeStartOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyCompleted = prefs.getBool(_kOnboardingCompleteKey) ?? false;
    if (alreadyCompleted) return;

    // Delay so the play screen has time to lay out and
    // the GlobalKeys have valid RenderBoxes.
    await Future.delayed(const Duration(milliseconds: 600));

    state = state.copyWith(isActive: true, currentStepIndex: 0);
  }

  /// Advance to the next step. If on the last step, complete.
  void nextStep() {
    if (state.isLastStep) {
      _complete();
      return;
    }
    state = state.copyWith(currentStepIndex: state.currentStepIndex + 1);
  }

  /// Complete onboarding and pulse the connect wallet button.
  Future<void> finishWithHighlight() async {
    // Set both flags atomically, then persist in background
    state = state.copyWith(isActive: false, highlightWallet: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingCompleteKey, true);
  }

  /// Clear the wallet highlight.
  void clearHighlight() {
    state = state.copyWith(highlightWallet: false);
  }

  /// Skip the entire onboarding.
  void skip() => _complete();

  /// Mark onboarding as done and persist.
  Future<void> _complete() async {
    state = state.copyWith(isActive: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingCompleteKey, true);
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingState>(
        OnboardingNotifier.new);
