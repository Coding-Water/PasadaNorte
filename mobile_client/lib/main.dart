import 'package:flutter/material.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/views/welcome_onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const PasadaNorteMobileApp());
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
