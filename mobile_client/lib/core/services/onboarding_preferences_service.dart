import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages persistence for onboarding completion state.
/// Ensures that once a user completes or skips the walkthrough,
/// subsequent app launches navigate directly to the login screen.
class OnboardingPreferencesService {
  static const String _kOnboardingCompleted = 'pn_has_completed_onboarding';

  /// Returns true if the user has already completed or skipped the onboarding flow.
  static Future<bool> hasCompletedOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kOnboardingCompleted) ?? false;
    } catch (e) {
      debugPrint('OnboardingPreferencesService.hasCompletedOnboarding error: $e');
      return false;
    }
  }

  /// Marks the onboarding flow as completed/skipped so returning users go directly to login.
  static Future<void> markOnboardingCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kOnboardingCompleted, true);
    } catch (e) {
      debugPrint('OnboardingPreferencesService.markOnboardingCompleted error: $e');
    }
  }

  /// Resets onboarding status (useful for logout, testing, or reset).
  static Future<void> resetOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kOnboardingCompleted);
    } catch (e) {
      debugPrint('OnboardingPreferencesService.resetOnboarding error: $e');
    }
  }
}
