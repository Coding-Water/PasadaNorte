import 'package:flutter/material.dart';
import 'features/auth/views/login_screen.dart';

void main() {
  runApp(const PasadaNorteMobileApp());
}

class PasadaNorteMobileApp extends StatelessWidget {
  const PasadaNorteMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PasadaNorte Driver & Rider',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const LoginScreen(), 
    );
  }
}
