import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../fare/services/fare_calculator_service.dart';
import 'passenger_account_screen.dart';
import 'passenger_activity_screen.dart';
import 'rider_map_booking_screen.dart';
import 'saved_addresses_screen.dart';

class PassengerServiceHubScreen extends StatefulWidget {
  final String fullName;
  final PassengerCategory lockedCategory;
  final String verifiedIdType;
  final int initialTabIndex;

  const PassengerServiceHubScreen({
    super.key,
    required this.fullName,
    this.lockedCategory = PassengerCategory.regular,
    this.verifiedIdType = 'National ID (PhilID)',
    this.initialTabIndex = 0,
  });

  @override
  State<PassengerServiceHubScreen> createState() =>
      _PassengerServiceHubScreenState();
}

class _PassengerServiceHubScreenState extends State<PassengerServiceHubScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
  }


  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: _getBody(context),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Color(0xFFF1F5F9), width: 1.2),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            backgroundColor: Colors.white,
            elevation: 0,
            selectedItemColor: AppTheme.accentEmerald,
            unselectedItemColor: Colors.grey.shade400,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.location_on_outlined),
                activeIcon: Icon(Icons.location_on_rounded),
                label: 'Address',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.assignment_outlined),
                activeIcon: Icon(Icons.assignment_rounded),
                label: 'Activity',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: 'Account',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getBody(BuildContext context) {
    switch (_currentIndex) {
      case 0:
        return _buildHomeContent(context);
      case 1:
        return SavedAddressesScreen(
          fullName: widget.fullName,
          lockedCategory: widget.lockedCategory,
        );
      case 2:
        return PassengerActivityScreen(fullName: widget.fullName);
      case 3:
      default:
        return PassengerAccountScreen(
          fullName: widget.fullName,
          lockedCategory: widget.lockedCategory,
          verifiedIdType: widget.verifiedIdType,
        );
    }
  }

  Widget _buildHomeContent(BuildContext context) {
    final config = FareCalculatorService.activeConfig;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: const Text(
          'PasadaNorte',
          style: TextStyle(
            color: AppTheme.primarySlate,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8EF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 13,
                  color: AppTheme.accentEmerald,
                ),
                SizedBox(width: 4),
                Text(
                  'Laoag City',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.accentEmerald,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modern Greeting + Quick "Where to?" Hero Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00C466), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00C466).withValues(alpha: 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${widget.fullName.split(' ').first}!',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Where would you like to travel in Laoag City today?',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.white,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RiderMapBookingScreen(
                                fullName: widget.fullName,
                                lockedCategory: widget.lockedCategory,
                                initialTripType: TripType.standard,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.search_rounded,
                                color: AppTheme.accentEmerald,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Where are you going?',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F8EF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Book',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.accentEmerald,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              const Text(
                'Services',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primarySlate,
                ),
              ),
              const SizedBox(height: 14),

              // OPTION 1: BOOK A RIDE
              _buildServiceCard(
                context: context,
                badge: 'COMMUTER TRANSIT',
                title: 'Book a Ride',
                subtitle:
                    'Point-to-point tricycle ride anywhere in Laoag City. Pick destination, review fare breakdown, and hail driver.',
                icon: Icons.electric_rickshaw_rounded,
                imageAsset: 'assets/images/book_ride_icon.jpg',
                accentColor: AppTheme.accentEmerald,
                bgColor: const Color(0xFFE8F8EF),
                rateText: widget.lockedCategory == PassengerCategory.regular
                    ? '\u20B1${config.regularFirstKmFare.toStringAsFixed(0)} 1st km + \u20B1${config.succeedingKmRate.toStringAsFixed(0)}/km'
                    : '\u20B1${config.discountedFirstKmFare.toStringAsFixed(0)} Discounted 1st km + 20% off',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RiderMapBookingScreen(
                        fullName: widget.fullName,
                        lockedCategory: widget.lockedCategory,
                        initialTripType: TripType.standard,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 14),

              // OPTION 2: PA-DELIVER (ERRAND / PARCEL DELIVERY)
              _buildServiceCard(
                context: context,
                badge: 'PARCEL & MARKET ERRAND',
                title: 'PasaDeliver (Padala / Pabili)',
                subtitle:
                    'Send or receive documents, food, or public market packages with verified TODA dispatch and live GPS tracking.',
                icon: Icons.local_shipping_rounded,
                imageAsset: 'assets/images/pasadeliver_icon.jpg',
                accentColor: const Color(0xFFD97706),
                bgColor: const Color(0xFFFEF3C7),
                rateText: 'Ordinance Distance Rate + Handling Fee',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RiderMapBookingScreen(
                        fullName: widget.fullName,
                        lockedCategory: widget.lockedCategory,
                        initialTripType: TripType.pabiliPadala,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 8),
            ],
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
    String? imageAsset,
    required Color accentColor,
    required Color bgColor,
    required String rateText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: imageAsset != null
                      ? Image.asset(
                          imageAsset,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        )
                      : Icon(icon, color: accentColor, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        badge,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primarySlate,
                        ),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: accentColor,
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sell_rounded, size: 13, color: accentColor),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      rateText,
                      style: TextStyle(
                        fontSize: 11,
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
