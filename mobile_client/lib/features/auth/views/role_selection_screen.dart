import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../fare/services/fare_calculator_service.dart';
import '../models/user_model.dart';
import 'student_check_screen.dart';
import 'user_details_input_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  final String phoneNumber;

  const RoleSelectionScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Account Setup',
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
                'Are you a Passenger or a Driver?',
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
                'Choose how you want to use PasadaNorte in Laoag City.',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 22),

              // Centered Passenger / Driver split illustration
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/role_selection_hero.jpg',
                      fit: BoxFit.contain,
                      semanticLabel: 'Passenger on the left and PasadaNorte driver on the right',
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Two buttons side-by-side
              Row(
                children: [
                  Expanded(
                    child: _buildRoleButton(
                      label: 'Passenger',
                      icon: Icons.person_rounded,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StudentCheckScreen(phoneNumber: phoneNumber),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildRoleButton(
                      label: 'Driver',
                      icon: Icons.person_rounded,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserDetailsInputScreen(
                              phoneNumber: phoneNumber,
                              role: UserRole.driver,
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

  Widget _buildRoleButton({
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
