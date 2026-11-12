import 'package:flutter/material.dart';
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
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              const Text(
                'are you a senior or pwd',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 36),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: _buildPillButton(
                      label: 'yes',
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildPillButton(
                      label: 'no',
                      onTap: () {
                        // Automatic regular passenger
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
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.black, width: 2.0),
          shape: const StadiumBorder(),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
