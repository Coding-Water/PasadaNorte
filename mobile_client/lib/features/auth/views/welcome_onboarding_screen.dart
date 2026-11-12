import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/android_permissions_service.dart';
import 'phone_input_screen.dart';

class WelcomeOnboardingScreen extends StatefulWidget {
  const WelcomeOnboardingScreen({super.key});

  @override
  State<WelcomeOnboardingScreen> createState() =>
      _WelcomeOnboardingScreenState();
}

class _WelcomeOnboardingScreenState extends State<WelcomeOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // PasadaNorte Emerald & Joyride Palette
  static const Color _primaryGreen = Color(0xFF008744);
  static const Color _mintBackground = Color(0xFFE8F8EF);
  static const Color _darkHeading = Color(0xFF212121);
  static const Color _subtitleGrey = Color(0xFF757575);
  static const Color _dotInactive = Color(0xFFE0E0E0);

  final List<Map<String, String>> _slides = [
    {
      'title': 'Welcome to PasadaNorte - Your\nJourney, Your Way',
      'subtitle':
          "Get ready to experience hassle-free paratransit in Laoag City. We've got everything you need to travel with ease. Let's get started!",
    },
    {
      'title': 'Choose Your Ride -\nTailored to Your Needs',
      'subtitle':
          'Select your preferred tricycle ride tier - Pasada Regular or Discounted - and order a ride with upfront approved city fares.',
    },
    {
      'title': 'Secure Payments &\nSeamless Transactions',
      'subtitle':
          'Say hello to convenience payments. Pay for your rides securely using Cash, Maya, GCash QR Ph, or TODA terminal digital dispatch.',
    },
  ];

  @override
  void initState() {
    super.initState();
    // Warm up Android permissions in the background without blocking UI
    AndroidPermissionsService.getSavedState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleNavigation({required bool startInRegisterMode}) async {
    // Seamless permissions check before proceeding
    await AndroidPermissionsService.ensureAllPermissionsSequential(context);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhoneInputScreen(
          initialIsRegisterMode: startInRegisterMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final isCompact = screenHeight < 720;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // 1. Top Green Curved Background (Joyride Convex Bezier Arc)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: isCompact ? screenHeight * 0.54 : screenHeight * 0.58,
              child: ClipPath(
                clipper: const _JoyrideCurveClipper(),
                child: Container(
                  color: _primaryGreen,
                ),
              ),
            ),

            // 2. Main Layout (Phone Mockup on Top + White Bottom Sheet)
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Upper Hero Area with Floating Phone Mockup (NO top header bar!)
                  Expanded(
                    flex: isCompact ? 10 : 11,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final phoneWidth = math.min(
                              constraints.maxWidth * 0.78,
                              285.0,
                            );
                            final phoneHeight = math.min(
                              constraints.maxHeight * 0.95,
                              420.0,
                            );
                            return SizedBox(
                              width: phoneWidth,
                              height: phoneHeight,
                              child: _JoyridePhoneMockup(
                                currentPage: _currentPage,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // Lower White Card Area (Title, Subtitle, Dots, Buttons)
                  Expanded(
                    flex: isCompact ? 9 : 8,
                    child: Container(
                      width: double.infinity,
                      color: Colors.white,
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
                          child: Column(
                            children: [
                              // PageView for Titles & Subtitles
                              Expanded(
                                child: PageView.builder(
                                  controller: _pageController,
                                  itemCount: _slides.length,
                                  onPageChanged: (idx) =>
                                      setState(() => _currentPage = idx),
                                  itemBuilder: (context, index) {
                                    final slide = _slides[index];
                                    return Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          slide['title']!,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 23,
                                            fontWeight: FontWeight.w800,
                                            color: _darkHeading,
                                            letterSpacing: -0.5,
                                            height: 1.25,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          slide['subtitle']!,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w400,
                                            color: _subtitleGrey,
                                            height: 1.45,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),

                              // Indicator Dots (Active wide pill + inactive circles)
                              Semantics(
                                label:
                                    'Page ${_currentPage + 1} of ${_slides.length}',
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(_slides.length, (idx) {
                                    final isActive = _currentPage == idx;
                                    return AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 250),
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      width: isActive ? 32 : 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? _primaryGreen
                                            : _dotInactive,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Bottom Buttons Row (Exact Joyride 50/50 on slides 1 & 2, full-width on slide 3)
                              if (_currentPage < _slides.length - 1)
                                Row(
                                  children: [
                                    // Skip Button (Soft Mint Pill)
                                    Expanded(
                                      child: SizedBox(
                                        height: 54,
                                        child: ElevatedButton(
                                          onPressed: () => _handleNavigation(
                                            startInRegisterMode: false,
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _mintBackground,
                                            foregroundColor: _primaryGreen,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(27),
                                            ),
                                          ),
                                          child: const Text(
                                            'Skip',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Continue Button (Vibrant Emerald Pill)
                                    Expanded(
                                      child: SizedBox(
                                        height: 54,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            _pageController.nextPage(
                                              duration: const Duration(
                                                  milliseconds: 320),
                                              curve: Curves.easeOutCubic,
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _primaryGreen,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(27),
                                            ),
                                          ),
                                          child: const Text(
                                            'Continue',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              else
                                // Full-width "Let's Get Started"
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: () => _handleNavigation(
                                      startInRegisterMode: true,
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _primaryGreen,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(27),
                                      ),
                                    ),
                                    child: const Text(
                                      "Let's Get Started",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
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

// ---------------------------------------------------------------------------
// Smooth Convex Bezier Clipper matching Joyride Page 17-19
// ---------------------------------------------------------------------------
class _JoyrideCurveClipper extends CustomClipper<Path> {
  const _JoyrideCurveClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);
    // Smooth convex quadratic curve dipping down in the center
    path.quadraticBezierTo(
      size.width / 2,
      size.height + 25,
      size.width,
      size.height - 40,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ---------------------------------------------------------------------------
// High-Fidelity Phone Mockup (iPhone Chassis with Dynamic Island)
// ---------------------------------------------------------------------------
class _JoyridePhoneMockup extends StatelessWidget {
  final int currentPage;

  const _JoyridePhoneMockup({required this.currentPage});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF18181B), // Dark chassis
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: const Color(0xFF27272A), width: 3.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4.5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Container(
          color: const Color(0xFFF8FAFC),
          child: Column(
            children: [
              // Mini Status Bar with Dynamic Island
              Container(
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '9:41',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF18181B),
                      ),
                    ),
                    // Dynamic Island Pill
                    Container(
                      width: 58,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: Color(0xFF27272A),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Row(
                      children: [
                        Icon(Icons.wifi, size: 10, color: Color(0xFF18181B)),
                        SizedBox(width: 3),
                        Icon(Icons.battery_full, size: 11, color: Color(0xFF18181B)),
                      ],
                    ),
                  ],
                ),
              ),

              // Mockup Screen Content switching per slide
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildScreenContent(currentPage),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScreenContent(int index) {
    switch (index) {
      case 0:
        return const _Walkthrough1MapScreen(key: ValueKey('walkthrough_1'));
      case 1:
        return const _Walkthrough2RouteScreen(key: ValueKey('walkthrough_2'));
      case 2:
      default:
        return const _Walkthrough3PaymentScreen(key: ValueKey('walkthrough_3'));
    }
  }
}

// ---------------------------------------------------------------------------
// Screen 1: Passenger Map (Washington Square Park / Laoag Aurora Park Grid)
// ---------------------------------------------------------------------------
class _Walkthrough1MapScreen extends StatelessWidget {
  const _Walkthrough1MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Vector Street Map
        Positioned.fill(
          child: CustomPaint(
            painter: _MapGridPainter(),
          ),
        ),

        // Commuter Avatar Pin in Center (with Green Radar Pulse)
        Positioned(
          left: 105,
          top: 130,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF008744).withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF008744),
                        width: 2.2,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.person_rounded,
                        size: 13,
                        color: Color(0xFF008744),
                      ),
                    ),
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_drop_down,
                size: 14,
                color: Color(0xFF008744),
              ),
            ],
          ),
        ),

        // 4 Tricycles Scattered on Roads (Emerald & Gold)
        const Positioned(
          left: 36,
          top: 70,
          child: _MockTricycleVehicle(angle: 0.2),
        ),
        const Positioned(
          right: 32,
          top: 100,
          child: _MockTricycleVehicle(angle: -0.3),
        ),
        const Positioned(
          left: 55,
          bottom: 55,
          child: _MockTricycleVehicle(angle: 0.5),
        ),
        const Positioned(
          right: 48,
          bottom: 40,
          child: _MockTricycleVehicle(angle: -0.1),
        ),

        // Floating Target GPS Compass Button (Bottom Right)
        Positioned(
          right: 12,
          bottom: 12,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.my_location_rounded,
              color: Color(0xFF212121),
              size: 15,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Screen 2: Choose Your Ride (Origin -> Destination & Ride Selection Sheet)
// ---------------------------------------------------------------------------
class _Walkthrough2RouteScreen extends StatelessWidget {
  const _Walkthrough2RouteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Map with Route Polyline
        Positioned.fill(
          child: CustomPaint(
            painter: _RoutePolylinePainter(),
          ),
        ),

        // Top Floating Origin -> Destination Card
        Positioned(
          top: 8,
          left: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF008744),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Laoag Central Terminal',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF212121),
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.only(left: 3),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 1,
                    height: 8,
                    color: const Color(0xFFCBD5E1),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'MMSU Laoag Campus',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF212121),
                        ),
                      ),
                    ),
                    const Icon(Icons.add, size: 12, color: Color(0xFF008744)),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Bottom Sheet: Ride Options (Pasada Regular & Pasada Discounted)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Option 1: Pasada Regular (Selected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F8EF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF008744), width: 1.2),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.electric_rickshaw_rounded,
                        color: Color(0xFF008744),
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pasada Regular',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF212121),
                              ),
                            ),
                            Text(
                              '⏱ 3-5 mins • 👤 3 seats',
                              style: TextStyle(
                                fontSize: 7.5,
                                color: Color(0xFF757575),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₱20.00',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF008744),
                            ),
                          ),
                          Icon(
                            Icons.check_circle_rounded,
                            size: 12,
                            color: Color(0xFF008744),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Option 2: Pasada Discounted
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.electric_rickshaw_rounded,
                        color: Color(0xFFF59E0B),
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pasada Discounted',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF212121),
                              ),
                            ),
                            Text(
                              '⏱ 4-6 mins • 👤 3 seats',
                              style: TextStyle(
                                fontSize: 7.5,
                                color: Color(0xFF757575),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₱16.00',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF212121),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Screen 3: Choose Payment Method (Clean Cards Stack)
// ---------------------------------------------------------------------------
class _Walkthrough3PaymentScreen extends StatelessWidget {
  const _Walkthrough3PaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar (< Choose Payment Method +)
          const Row(
            children: [
              Icon(Icons.arrow_back, size: 12, color: Color(0xFF212121)),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Choose Payment Method',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF212121),
                  ),
                ),
              ),
              Icon(Icons.add, size: 12, color: Color(0xFF212121)),
            ],
          ),
          const SizedBox(height: 12),

          // Card 1: Pasada Wallet (Selected with check)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF008744), width: 1.2),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF008744),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 13,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pasada Wallet',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF212121),
                        ),
                      ),
                      Text(
                        'Available balance: ₱500.00',
                        style: TextStyle(
                          fontSize: 7.5,
                          color: Color(0xFF757575),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF008744),
                  size: 14,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Card 2: Cash
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Color(0xFF008744),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.attach_money_rounded,
                    color: Colors.white,
                    size: 13,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cash',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF212121),
                        ),
                      ),
                      Text(
                        'Pay drivers cash directly',
                        style: TextStyle(
                          fontSize: 7.5,
                          color: Color(0xFF757575),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Card 3: Maya / GCash QR Ph
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    color: Colors.white,
                    size: 13,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Maya / GCash (QR Ph)',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF212121),
                        ),
                      ),
                      Text(
                        'Instant BSP QR code scan',
                        style: TextStyle(
                          fontSize: 7.5,
                          color: Color(0xFF757575),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Card 4: TODA Guarantee
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: Colors.white,
                    size: 13,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TODA Digital Pila Guarantee',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF212121),
                        ),
                      ),
                      Text(
                        'Verified driver, 100% fair dispatch',
                        style: TextStyle(
                          fontSize: 7.5,
                          color: Color(0xFF757575),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Realistic Top-Down Mock Tricycle Vehicle on Roads
// ---------------------------------------------------------------------------
class _MockTricycleVehicle extends StatelessWidget {
  final double angle;

  const _MockTricycleVehicle({required this.angle});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF008744), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.electric_rickshaw_rounded,
              color: Color(0xFF008744),
              size: 11,
            ),
            SizedBox(width: 2),
            Icon(
              Icons.circle,
              color: Color(0xFFF59E0B),
              size: 4,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom Painters for Realistic Vector Street Grids
// ---------------------------------------------------------------------------
class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Map Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFF1F5F9),
    );

    // Green Park Area (Washington Square Park / Aurora Park)
    final parkPaint = Paint()..color = const Color(0xFFDCFCE7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.32,
          size.height * 0.38,
          size.width * 0.38,
          size.height * 0.22,
        ),
        const Radius.circular(8),
      ),
      parkPaint,
    );

    // Roads
    final borderPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9;

    final roadPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;

    void drawRoad(Path p) {
      canvas.drawPath(p, borderPaint);
      canvas.drawPath(p, roadPaint);
    }

    // Grid Roads
    final h1 = Path()
      ..moveTo(0, size.height * 0.22)
      ..lineTo(size.width, size.height * 0.22);
    drawRoad(h1);

    final h2 = Path()
      ..moveTo(0, size.height * 0.65)
      ..lineTo(size.width, size.height * 0.65);
    drawRoad(h2);

    final v1 = Path()
      ..moveTo(size.width * 0.25, 0)
      ..lineTo(size.width * 0.25, size.height);
    drawRoad(v1);

    final v2 = Path()
      ..moveTo(size.width * 0.75, 0)
      ..lineTo(size.width * 0.75, size.height);
    drawRoad(v2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RoutePolylinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _MapGridPainter().paint(canvas, size);

    // Green Polyline Route
    final routeWhiteBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final routePaint = Paint()
      ..color = const Color(0xFF008744)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final routePath = Path()
      ..moveTo(size.width * 0.25, size.height * 0.22)
      ..lineTo(size.width * 0.25, size.height * 0.65)
      ..lineTo(size.width * 0.75, size.height * 0.65)
      ..lineTo(size.width * 0.75, size.height * 0.45);

    canvas.drawPath(routePath, routeWhiteBorder);
    canvas.drawPath(routePath, routePaint);

    // Start Pin (Laoag Central Terminal)
    canvas.drawCircle(
      Offset(size.width * 0.25, size.height * 0.22),
      5.5,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(size.width * 0.25, size.height * 0.22),
      3.8,
      Paint()..color = const Color(0xFF008744),
    );

    // Destination Pin (MMSU Campus)
    canvas.drawCircle(
      Offset(size.width * 0.75, size.height * 0.45),
      5.5,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(size.width * 0.75, size.height * 0.45),
      3.8,
      Paint()..color = const Color(0xFFEF4444),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
