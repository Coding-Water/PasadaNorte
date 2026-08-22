import 'package:flutter/material.dart';
import 'features/auth/views/login_screen.dart';

void main() {
  runApp(const TrikrMobileApp());
}

class TrikrMobileApp extends StatelessWidget {
  const TrikrMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Trikr Driver & Rider',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const LoginScreen(), // Boots directly into your auth screen
    );
  }
}
