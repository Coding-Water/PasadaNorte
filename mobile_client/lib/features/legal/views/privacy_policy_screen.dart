import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
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
                    'PasadaNorte ("PasadaNorte", "we", "us", or "our") respects the privacy of our riders and partner tricycle drivers ("you" or "your"). This Privacy Policy explains how we collect, use, disclose, and protect your personal information in compliance with the Philippine Data Privacy Act of 2012 (Republic Act No. 10173) and National Privacy Commission (NPC) guidelines when you use our mobile application and Laoag City paratransit services.',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.black87,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 22),

                  _buildSectionTitle('1. Information We Collect'),
                  _buildBullet(
                    'Account Information:',
                    'When you create a PasadaNorte account, we collect your name (last name, first name, middle name, suffix), verified mobile phone number, gender, date of birth, passenger classification (Regular, Student, Senior Citizen, or PWD), and optional profile picture.',
                  ),
                  _buildBullet(
                    'Identity & Biometric Verification (RA 10173 Sec. 13 & NPC Circular No. 2023-03):',
                    'To prevent ghost accounts and verify statutory fare discounts or TODA driver eligibility, we process photos of your valid ID (or driver clearances and vehicle OR/CR) and perform 1:1 facial similarity comparison with your live selfie.',
                  ),
                  _buildBullet(
                    'Location & Telemetry Information:',
                    'We collect real-time GPS pickup/dropoff coordinates, road-route distances for ordinance fare computation, and FIFO TODA terminal queue ("Digital Pila") status while the app is active.',
                  ),
                  _buildBullet(
                    'Payment & Transaction Records:',
                    'We record trip receipts, fare breakdowns, and cash or e-wallet (GCash / Maya QR Ph) settlement statuses.',
                  ),
                  const SizedBox(height: 16),

                  _buildSectionTitle('2. How We Use Your Information'),
                  _buildBullet(
                    'Service Delivery & Dispatch:',
                    'To match passengers with verified Laoag City TODA tricycle drivers, compute fixed City Ordinance fares, and provide Pa-Deliver tracking.',
                  ),
                  _buildBullet(
                    'Safety & Fraud Prevention:',
                    'To protect riders and drivers through verified identities, emergency SOS hotlines (Laoag PNP & CDRRMO), and trip history audit logs.',
                  ),
                  const SizedBox(height: 16),

                  _buildSectionTitle('3. Data Protection & Your Rights'),
                  const Text(
                    'We implement strict encryption and role-based access controls. Under RA 10173, you have the right to access, correct, or request deletion of your personal data, and to withdraw consent for optional processing at any time through Account Settings or by contacting our Data Protection Officer in Laoag City.',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.black87,
                      height: 1.55,
                    ),
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
      padding: const EdgeInsets.only(bottom: 10.0),
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

  Widget _buildBullet(String lead, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0, left: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.accentEmerald)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13.5, color: Colors.black87, height: 1.5),
                children: [
                  TextSpan(
                    text: '$lead ',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primarySlate),
                  ),
                  TextSpan(text: body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
