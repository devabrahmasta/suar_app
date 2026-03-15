import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingNotifier extends Notifier<bool> {
  @override
  bool build(){
    return false;
  }

  void completeOnboarding(){
    state = true;
  }
}

final onboardingStateProvider = NotifierProvider<OnboardingNotifier, bool>((){
  return OnboardingNotifier();
});