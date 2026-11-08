import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../admin/views/web_admin_portal_screen.dart';
import '../../auth/views/welcome_onboarding_screen.dart';
import '../../fare/services/fare_calculator_service.dart';
import 'rider_map_booking_screen.dart';

class PassengerServiceHubScreen extends StatelessWidget {
  final String fullName;
  final PassengerCategory lockedCategory;
  final String verifiedIdType;

  const PassengerServiceHubScreen({
    super.key,
    required this.fullName,
    this.lockedCategory = PassengerCategory.regular,
    this.verifiedIdType = 'National ID (PhilID)',
  });

  void _returnToHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeOnboardingScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = FareCalculatorService.activeConfig;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _returnToHome(context);
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back to Home',
            onPressed: () => _returnToHome(context),
            icon: const Icon(Icons.home_rounded),
          ),
          title: const Text('PasadaNorte'),
          actions: [
            IconButton(
              tooltip: 'TODA/MINC Admin Portal',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WebAdminPortalScreen()),
                );
              },
              icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.amber),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What would you like to do today?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primarySlate,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Select a service below. Your verified ${lockedCategory.name.toUpperCase()} rate is automatically applied to your bill.',
                  style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 22),

                // OPTION 1: BOOK A RIDE
                _buildServiceCard(
                  context: context,
                  badge: 'COMMUTER TRANSIT',
                  title: 'Book a Ride',
                  subtitle:
                      'Point-to-point tricycle ride anywhere in Laoag City. Pick your destination on the map, review your Bill Summary, and choose your payment method.',
                  icon: Icons.electric_rickshaw_rounded,
                  accentColor: AppTheme.accentEmerald,
                  bgColor: const Color(0xFFF0FDF4),
                  rateText: lockedCategory == PassengerCategory.regular
                      ? '₱${config.regularFirstKmFare.toStringAsFixed(0)} 1st km + ₱${config.succeedingKmRate.toStringAsFixed(0)}/km'
                      : '₱${config.discountedFirstKmFare.toStringAsFixed(0)} Discounted 1st km + 20% off succ. km',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RiderMapBookingScreen(
                          fullName: fullName,
                          lockedCategory: lockedCategory,
                          initialTripType: TripType.standard,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 18),

                // OPTION 2: PA-DELIVER (ERRAND / PARCEL DELIVERY)
                _buildServiceCard(
                  context: context,
                  badge: 'PARCEL & MARKET ERRAND',
                  title: 'Pa-Deliver (Padala / Pabili)',
                  subtitle:
                      'Book a verified TODA tricycle driver to deliver packages, documents, food, or public market goods across Laoag City with live GPS tracking.',
                  icon: Icons.local_shipping_rounded,
                  accentColor: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFFFBEB),
                  rateText: 'Ordinance Distance Rate + Delivery Handling (1.25x)',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RiderMapBookingScreen(
                          fullName: fullName,
                          lockedCategory: lockedCategory,
                          initialTripType: TripType.pabiliPadala,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceCard({
    required BuildContext context,
    required String badge,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    required String rateText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accentColor.withValues(alpha: 0.45), width: 1.8),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: accentColor, size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        badge,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primarySlate,
                        ),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: accentColor,
                  child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sell_rounded, size: 14, color: accentColor),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      rateText,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
