import 'dart:async';
import 'package:flutter/material.dart';
import 'core/services/supabase_service.dart';
import 'core/services/system_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/views/welcome_onboarding_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PasadaNorteMobileApp());
  unawaited(SupabaseService.initialize());
  unawaited(SystemNotificationService.initialize());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    debugPrint('First frame rendered successfully — UI is active and ready.');
  });
}

class PasadaNorteMobileApp extends StatelessWidget {
  const PasadaNorteMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PasadaNorte Laoag City',
      theme: AppTheme.lightTheme,
      home: const WelcomeOnboardingScreen(),
    );
  }
}
