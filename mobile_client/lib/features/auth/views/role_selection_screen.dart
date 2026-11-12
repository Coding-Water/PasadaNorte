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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Account Setup'),
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
                  'STEP 1 OF 4: ACCOUNT ROLE',
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
                'Are you a Passenger or a Driver?',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primarySlate,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose how you want to use PasadaNorte in Laoag City. Your account setup will tailor options specifically for you.',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),

              // Button 1: Passenger / Commuter
              _buildRoleCard(
                context: context,
                icon: Icons.directions_walk_rounded,
                iconColor: AppTheme.accentEmerald,
                iconBg: const Color(0xFFDCFCE7),
                title: 'Passenger / Commuter',
                subtitle: 'Book tricycle rides, request Pa-Deliver, and access fixed ordinance fares with student, senior, or regular rates.',
                badgeText: 'Ride & Delivery Booking',
                badgeColor: const Color(0xFF15803D),
                badgeBg: const Color(0xFFDCFCE7),
                borderColor: AppTheme.accentEmerald,
                backgroundColor: const Color(0xFFF0FDF4),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StudentCheckScreen(phoneNumber: phoneNumber),
                    ),
                  );
                },
              ),

              const SizedBox(height: 18),

              // Button 2: Tricycle Driver (TODA)
              _buildRoleCard(
                context: context,
                icon: Icons.electric_rickshaw_rounded,
                iconColor: const Color(0xFFD97706),
                iconBg: const Color(0xFFFEF3C7),
                title: 'Tricycle Driver (TODA)',
                subtitle: 'Accept passenger bookings and deliveries across Laoag City, view thermal demand heatmaps, and join Digital Pila queues.',
                badgeText: 'Laoag Paratransit Franchise',
                badgeColor: const Color(0xFFB45309),
                badgeBg: const Color(0xFFFEF3C7),
                borderColor: const Color(0xFFF59E0B),
                backgroundColor: const Color(0xFFFFFBEB),
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

              const SizedBox(height: 32),

              // Information banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: AppTheme.primarySlate, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Verified identity ensures zero ghost accounts and protects ordinance fare compliance under City Ordinance No. 2023-005.',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: iconColor, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
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
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.black38, size: 18),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    height: 1.45,
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
