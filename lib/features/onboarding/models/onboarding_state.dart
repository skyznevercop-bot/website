/// Represents a single onboarding step.
class OnboardingStep {
  final String id;
  final String title;
  final String description;

  const OnboardingStep({
    required this.id,
    required this.title,
    required this.description,
  });
}

/// All onboarding steps in order.
class OnboardingSteps {
  OnboardingSteps._();

  static const List<OnboardingStep> steps = [
    OnboardingStep(
      id: 'hero',
      title: 'Welcome to SolFight',
      description:
          'This is the Arena — where 1v1 trading battles happen. '
          'Pick your settings and fight for the pot.',
    ),
    OnboardingStep(
      id: 'timeframe',
      title: 'Choose Your Timeframe',
      description:
          'Scroll the wheel to pick how long your match lasts. '
          'Shorter matches are faster and more intense.',
    ),
    OnboardingStep(
      id: 'betAmount',
      title: 'Set Your Bet',
      description:
          'Choose how much USDC to wager. '
          'The winner takes the entire pot.',
    ),
    OnboardingStep(
      id: 'matchInfo',
      title: 'Check Match Details',
      description:
          'See the total pot size, how many players are in queue, '
          'and the estimated wait time before your match starts.',
    ),
    OnboardingStep(
      id: 'connectWallet',
      title: 'Connect & Fight!',
      description:
          'Link your Solana wallet, deposit USDC, and hit Join Queue '
          'to get matched with an opponent automatically.',
    ),
  ];
}

/// Immutable onboarding overlay state.
class OnboardingState {
  final bool isActive;
  final int currentStepIndex;
  final bool highlightWallet;

  const OnboardingState({
    this.isActive = false,
    this.currentStepIndex = 0,
    this.highlightWallet = false,
  });

  int get totalSteps => OnboardingSteps.steps.length;
  bool get isLastStep => currentStepIndex >= totalSteps - 1;
  OnboardingStep get currentStep => OnboardingSteps.steps[currentStepIndex];

  OnboardingState copyWith({
    bool? isActive,
    int? currentStepIndex,
    bool? highlightWallet,
  }) {
    return OnboardingState(
      isActive: isActive ?? this.isActive,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      highlightWallet: highlightWallet ?? this.highlightWallet,
    );
  }
}
