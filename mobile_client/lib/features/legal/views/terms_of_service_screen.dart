import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Terms of Service',
          style: TextStyle(
            color: AppTheme.primarySlate,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.primarySlate, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ScrollbarTheme(
          data: ScrollbarThemeData(
            thumbColor: WidgetStateProperty.all(AppTheme.accentEmerald),
            radius: const Radius.circular(8),
            thickness: WidgetStateProperty.all(4),
          ),
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 28, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Effective Date: November 13, 2026',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primarySlate,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'These Terms of Service ("Terms") govern your access to and use of the PasadaNorte mobile application ("App") and Laoag City tricycle ride-hailing, Digital Pila, and Pa-Deliver services ("Services") operated by PasadaNorte.',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.black87,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 22),

                  _buildSectionTitle('1. User Agreement'),
                  const Text(
                    'By creating an account or using PasadaNorte Services, you agree to be bound by these Terms and applicable Laoag City Paratransit Ordinances. If you do not agree, please discontinue use of the App.',
                    style: TextStyle(fontSize: 13.5, color: Colors.black87, height: 1.55),
                  ),
                  const SizedBox(height: 18),

                  _buildSectionTitle('2. Account Creation & Verification'),
                  const Text(
                    'All users must provide accurate legal details and a valid government, school, OSCA/PWD ID, or professional driver\'s license. Drivers must be between 20 and 55 years old with valid LTO OR/CR and clearances.',
                    style: TextStyle(fontSize: 13.5, color: Colors.black87, height: 1.55),
                  ),
                  const SizedBox(height: 18),

                  _buildSectionTitle('3. Your Responsibilities'),
                  _buildBullet('Maintain the confidentiality of your account and OTP login credentials.'),
                  _buildBullet('Honor confirmed bookings, Digital Pila queue rules, and fixed Laoag City ordinance fares (including statutory 20% Student, Senior Citizen, and PWD discounts).'),
                  _buildBullet('Treat PasadaNorte drivers, passengers, and support personnel with respect and refrain from fraudulent or unsafe conduct.'),
                  const SizedBox(height: 18),

                  _buildSectionTitle('4. Fares & Settlements'),
                  const Text(
                    'Fares are transparently calculated based on Laoag City Ordinance rates prior to booking confirmation. Payments may be settled in Cash or supported QR Ph e-wallets (GCash / Maya).',
                    style: TextStyle(fontSize: 13.5, color: Colors.black87, height: 1.55),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15.5,
          fontWeight: FontWeight.w800,
          color: AppTheme.primarySlate,
        ),
      ),
    );
  }

  Widget _buildBullet(String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.accentEmerald)),
          Expanded(
            child: Text(
              body,
              style: const TextStyle(fontSize: 13.5, color: Colors.black87, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
