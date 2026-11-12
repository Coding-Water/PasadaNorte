import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../fare/services/fare_calculator_service.dart';
import '../models/user_model.dart';
import 'senior_pwd_check_screen.dart';
import 'user_details_input_screen.dart';

class StudentCheckScreen extends StatelessWidget {
  final String phoneNumber;

  const StudentCheckScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Passenger Classification'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'STEP 2 OF 4: FARE DISCOUNT ELIGIBILITY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.accentEmeraldDark,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              const Text(
                'Are you a Student?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primarySlate,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Under Republic Act No. 11314 (Student Fare Discount Act), elementary, high school, college, and technical-vocational students in Laoag City are legally entitled to a 20% fare discount all year round.',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),

              // Option 1: Yes, I am a Student
              _buildChoiceCard(
                context: context,
                icon: Icons.school_rounded,
                iconColor: AppTheme.accentEmerald,
                iconBg: const Color(0xFFDCFCE7),
                title: 'Yes, I am a Student',
                description: 'Lock in 20% discounted fare (₱15.00 first km + succeeding discounts). Requires a photo of your validated School/Student ID in the next step.',
                badgeText: '20% Student Discount (₱15.00 1st km)',
                badgeColor: const Color(0xFF15803D),
                badgeBg: const Color(0xFFDCFCE7),
                borderColor: AppTheme.accentEmerald,
                backgroundColor: const Color(0xFFF0FDF4),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserDetailsInputScreen(
                        phoneNumber: phoneNumber,
                        role: UserRole.rider,
                        passengerCategory: PassengerCategory.student,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Option 2: No, I am not a Student
              _buildChoiceCard(
                context: context,
                icon: Icons.arrow_forward_rounded,
                iconColor: AppTheme.primarySlate,
                iconBg: const Color(0xFFF1F5F9),
                title: 'No, I am not a Student',
                description: 'Proceed to check if you are eligible for the Senior Citizen or Person with Disability (PWD) discount.',
                badgeText: 'Check Next Category',
                badgeColor: AppTheme.primarySlate,
                badgeBg: const Color(0xFFF1F5F9),
                borderColor: Colors.grey.shade300,
                backgroundColor: Colors.white,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SeniorPwdCheckScreen(phoneNumber: phoneNumber),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String description,
    required String badgeText,
    required Color badgeColor,
    required Color badgeBg,
    required Color borderColor,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: iconColor, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primarySlate,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 24),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
