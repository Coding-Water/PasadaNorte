import 'dart:async';
import 'package:flutter/material.dart';
import 'core/services/onboarding_preferences_service.dart';
import 'core/services/supabase_service.dart';
import 'core/services/system_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/views/phone_input_screen.dart';
import 'features/auth/views/welcome_onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final hasCompletedOnboarding =
      await OnboardingPreferencesService.hasCompletedOnboarding();
  runApp(PasadaNorteMobileApp(showLoginDirectly: hasCompletedOnboarding));
  unawaited(SupabaseService.initialize());
  unawaited(SystemNotificationService.initialize());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    debugPrint('First frame rendered successfully — UI is active and ready.');
  });
}

class PasadaNorteMobileApp extends StatelessWidget {
  final bool showLoginDirectly;

  const PasadaNorteMobileApp({
    super.key,
    this.showLoginDirectly = false,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PasadaNorte Laoag City',
      theme: AppTheme.lightTheme,
      home: showLoginDirectly
          ? const PhoneInputScreen(initialIsRegisterMode: false)
          : const WelcomeOnboardingScreen(),
    );
  }
}
