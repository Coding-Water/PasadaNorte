import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/views/phone_input_screen.dart';

void main() {
  runApp(const PasadaNorteMobileApp());
}

class PasadaNorteMobileApp extends StatelessWidget {
  const PasadaNorteMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pasada Norte',
      theme: AppTheme.lightTheme,
      home: const PhoneInputScreen(),
    );
  }
}
