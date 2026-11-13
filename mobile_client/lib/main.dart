import 'dart:async';
import 'package:flutter/material.dart';
import 'core/services/onboarding_preferences_service.dart';
import 'core/services/session_cache_service.dart';
import 'core/services/supabase_service.dart';
import 'core/services/system_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/views/driver_application_status_screen.dart';
import 'features/auth/views/phone_input_screen.dart';
import 'features/auth/views/welcome_onboarding_screen.dart';
import 'features/driver/views/driver_map_duty_screen.dart';
import 'features/fare/services/fare_calculator_service.dart';
import 'features/rider/views/passenger_service_hub_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final hasCompletedOnboarding =
      await OnboardingPreferencesService.hasCompletedOnboarding();
  final savedSession = await SessionCacheService.getSavedSession();
  runApp(
    PasadaNorteMobileApp(
      showLoginDirectly: hasCompletedOnboarding,
      savedSession: savedSession,
    ),
  );
  unawaited(SupabaseService.initialize());
  unawaited(SystemNotificationService.initialize());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    debugPrint('First frame rendered successfully — UI is active and ready.');
  });
}

class PasadaNorteMobileApp extends StatelessWidget {
  final bool showLoginDirectly;
  final CachedSession? savedSession;

  const PasadaNorteMobileApp({
    super.key,
    this.showLoginDirectly = false,
    this.savedSession,
  });

  Widget _resolveInitialHome() {
    final session = savedSession;
    if (session != null) {
      if (session.role == 'driver') {
        if (session.isPendingReview) {
          return DriverApplicationStatusScreen(
            phoneNumber: session.phoneNumber,
            fullName: session.fullName,
          );
        }
        return DriverMapDutyScreen(fullName: session.fullName);
      }

      final idTypeStr = session.idType ?? 'National ID (PhilID)';
      PassengerCategory lockedCat = PassengerCategory.regular;
      if (idTypeStr.toUpperCase().contains('STUDENT')) {
        lockedCat = PassengerCategory.student;
      } else if (idTypeStr.toUpperCase().contains('SENIOR') ||
          idTypeStr.toUpperCase().contains('PWD')) {
        lockedCat = PassengerCategory.senior;
      }
      return PassengerServiceHubScreen(
        fullName: session.fullName,
        lockedCategory: lockedCat,
        verifiedIdType: idTypeStr,
      );
    }

    return showLoginDirectly
        ? const PhoneInputScreen(initialIsRegisterMode: false)
        : const WelcomeOnboardingScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PasadaNorte Laoag City',
      theme: AppTheme.lightTheme,
      home: _resolveInitialHome(),
    );
  }
}
