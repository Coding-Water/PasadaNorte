import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../fare/services/fare_calculator_service.dart';
import '../models/user_model.dart';
import 'user_details_input_screen.dart';

class SeniorPwdCheckScreen extends StatelessWidget {
  final String phoneNumber;

  const SeniorPwdCheckScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Passenger Classification',
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Are you a Senior Citizen or PWD?',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primarySlate,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Senior citizens (60+) and PWDs receive a 20% statutory discount (₱15.00 1st km) under RA 9994 and RA 10754.',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 22),

              // Centered Senior Citizen / PWD split illustration
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/senior_pwd_hero.jpg',
                      fit: BoxFit.contain,
                      semanticLabel: 'Senior citizen on the left and person with disability on the right',
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Two buttons side-by-side
              Row(
                children: [
                  Expanded(
                    child: _buildChoiceButton(
                      label: 'Yes, Senior / PWD',
                      icon: Icons.accessible_rounded,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserDetailsInputScreen(
                              phoneNumber: phoneNumber,
                              role: UserRole.rider,
                              passengerCategory: PassengerCategory.senior,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildChoiceButton(
                      label: 'Regular Passenger',
                      icon: Icons.person_rounded,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserDetailsInputScreen(
                              phoneNumber: phoneNumber,
                              role: UserRole.rider,
                              passengerCategory: PassengerCategory.regular,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.accentEmeraldDark, width: 1.8),
          shape: const StadiumBorder(),
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.accentEmerald,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.accentEmerald, size: 19),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentEmerald,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
