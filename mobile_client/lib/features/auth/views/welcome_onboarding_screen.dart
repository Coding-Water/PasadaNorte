import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/services/android_permissions_service.dart';
import '../../../core/theme/app_theme.dart';
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
  AndroidPermissionsState _permState = const AndroidPermissionsState(
    locationGranted: false,
    isPreciseLocation: true,
    notificationsGranted: false,
    cameraGranted: false,
    galleryGranted: false,
  );

  static const Color _emerald = Color(0xFF007A37);
  static const Color _emeraldDeep = Color(0xFF005826);
  static const Color _gold = Color(0xFFF59E0B);
  static const Color _goldDeep = Color(0xFFD97706);

  final List<Map<String, dynamic>> _slides = [
    {
      'badge': 'LAOAG CITY COMMUTE',
      'title': 'Welcome to PasadaNorte — Your Journey, Your Way',
      'subtitle':
          'Experience hassle-free tricycle mobility across Laoag City. Book certified rides with real-time GPS tracking and fair city-approved rates.',
    },
    {
      'badge': 'ORDINANCE NO. 2023-005',
      'title': 'Choose Your Ride — Approved City Fares',
      'subtitle':
          'Upfront fare computation based on actual road distance. Standard ₱20 base fare with automated 20% statutory discounts for students & seniors.',
    },
    {
      'badge': 'FAIR TERMINAL PILA',
      'title': 'Fair TODA Digital Pila & Flexible Payments',
      'subtitle':
          'Pay with cash in hand or scan QR Ph with zero surge pricing. Every ride is dispatched through the verified TODA queue system.',
    },
  ];

  @override
  void initState() {
    super.initState();
    AndroidPermissionsService.getSavedState().then((state) {
      if (mounted) setState(() => _permState = state);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkAndPromptAndroidPermissions({bool forceShowAll = false}) async {
    final updated = await AndroidPermissionsService.ensureAllPermissionsSequential(
      context,
      forceShowAll: forceShowAll,
    );
    if (!mounted) return;
    setState(() {
      _permState = updated;
    });
  }

  Future<void> _goToAuth({required bool startInRegisterMode}) async {
    await _checkAndPromptAndroidPermissions();
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
    final isCompact = screenHeight < 700;

    return Scaffold(
      backgroundColor: _emerald,
      body: Stack(
        children: [
          // Background Gradient with Emerald & subtle Gold depth
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_emerald, _emeraldDeep],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Navigation Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Brand Logo & Title
                      Semantics(
                        header: true,
                        label: 'PasadaNorte Laoag City',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.asset(
                                'assets/images/pasadanorte_logo.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.electric_rickshaw_rounded,
                                  color: _emerald,
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'PasadaNorte',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Text(
                                  'Laoag City • Ilocos Norte',
                                  style: TextStyle(
                                    color: Color(0xFFFDE68A),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Permissions Pill & Skip Button
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Semantics(
                            button: true,
                            label: _permState.allGranted
                                ? 'Permissions 4 of 4 active'
                                : 'Permissions review required',
                            child: InkWell(
                              onTap: () =>
                                  _checkAndPromptAndroidPermissions(forceShowAll: true),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                constraints: const BoxConstraints(minHeight: 48),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _permState.allGranted
                                        ? const Color(0xFF4ADE80)
                                        : _gold,
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _permState.allGranted
                                          ? Icons.verified_user_rounded
                                          : Icons.tune_rounded,
                                      color: _permState.allGranted
                                          ? const Color(0xFF4ADE80)
                                          : _gold,
                                      size: 13,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _permState.allGranted ? '4/4' : 'Perms',
                                      style: TextStyle(
                                        color: _permState.allGranted
                                            ? const Color(0xFF4ADE80)
                                            : _gold,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Semantics(
                            button: true,
                            label: 'Skip onboarding to login screen',
                            child: TextButton(
                              onPressed: () => _goToAuth(startInRegisterMode: false),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.white.withValues(alpha: 0.16),
                                minimumSize: const Size(54, 48),
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: const Text(
                                'Skip',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Hero Section: Floating Phone Mockup Displaying Passenger Screens
                Expanded(
                  flex: isCompact ? 5 : 6,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final phoneWidth = math.min(constraints.maxWidth * 0.76, 275.0);
                          final phoneHeight = math.min(constraints.maxHeight * 0.94, 390.0);
                          return SizedBox(
                            width: phoneWidth,
                            height: phoneHeight,
                            child: _PhoneMockup(currentPage: _currentPage),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // Bottom Curved White Sheet
                Expanded(
                  flex: isCompact ? 4 : 4,
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 24,
                          offset: Offset(0, -6),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        children: [
                          // PageView Content (Title & Subtitle)
                          Expanded(
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: _slides.length,
                              onPageChanged: (idx) =>
                                  setState(() => _currentPage = idx),
                              itemBuilder: (context, index) {
                                final slide = _slides[index];
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 4),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Gold/Emerald Tag
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: _gold.withValues(alpha: 0.6),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          slide['badge'] as String,
                                          style: const TextStyle(
                                            color: _goldDeep,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.7,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        slide['title'] as String,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.primarySlate,
                                          letterSpacing: -0.4,
                                          height: 1.22,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        slide['subtitle'] as String,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF475569),
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),

                          // Indicator Dots
                          Semantics(
                            label: 'Slide ${_currentPage + 1} of ${_slides.length}',
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(_slides.length, (idx) {
                                final isActive = _currentPage == idx;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  width: isActive ? 26 : 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: isActive ? _emerald : const Color(0xFFCBD5E1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Navigation Action Buttons
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                            child: _currentPage < _slides.length - 1
                                ? Row(
                                    children: [
                                      // Skip Button (Soft Left)
                                      Expanded(
                                        flex: 2,
                                        child: SizedBox(
                                          height: 50,
                                          child: TextButton(
                                            onPressed: () =>
                                                _goToAuth(startInRegisterMode: false),
                                            style: TextButton.styleFrom(
                                              backgroundColor: const Color(0xFFF1F5F9),
                                              foregroundColor: const Color(0xFF475569),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(25),
                                              ),
                                            ),
                                            child: const Text(
                                              'Skip',
                                              style: TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Continue Button (Emerald Right Pill)
                                      Expanded(
                                        flex: 3,
                                        child: SizedBox(
                                          height: 50,
                                          child: ElevatedButton(
                                            onPressed: () {
                                              _pageController.nextPage(
                                                duration:
                                                    const Duration(milliseconds: 320),
                                                curve: Curves.easeOutCubic,
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: _emerald,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(25),
                                              ),
                                            ),
                                            child: const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'Continue',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                SizedBox(width: 6),
                                                Icon(
                                                  Icons.arrow_forward_rounded,
                                                  size: 18,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Full-width Get Started
                                      SizedBox(
                                        width: double.infinity,
                                        height: 52,
                                        child: ElevatedButton(
                                          onPressed: () =>
                                              _goToAuth(startInRegisterMode: true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _emerald,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(26),
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                "Let's Get Started",
                                                style: TextStyle(
                                                  fontSize: 15.5,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Icon(Icons.arrow_forward_rounded, size: 20),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      // Secondary Log In link
                                      SizedBox(
                                        height: 48,
                                        child: TextButton(
                                          onPressed: () =>
                                              _goToAuth(startInRegisterMode: false),
                                          style: TextButton.styleFrom(
                                            foregroundColor: _emerald,
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                          ),
                                          child: const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Already have an account? ',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                              Text(
                                                'Log In',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                  color: _emerald,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
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
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Realistic Floating Phone Mockup displaying PasadaNorte Passenger Screens
// ---------------------------------------------------------------------------
class _PhoneMockup extends StatelessWidget {
  final int currentPage;

  const _PhoneMockup({required this.currentPage});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: const Color(0xFF334155), width: 3.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.38),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          color: const Color(0xFFF8FAFC),
          child: Column(
            children: [
              // Phone Top Status Bar & Dynamic Island
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
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    // Dynamic Island Pill
                    Container(
                      width: 52,
                      height: 11,
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
                              color: Color(0xFF1E293B),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Row(
                      children: [
                        Icon(Icons.wifi, size: 10, color: Color(0xFF0F172A)),
                        SizedBox(width: 3),
                        Icon(Icons.battery_full, size: 11, color: Color(0xFF0F172A)),
                      ],
                    ),
                  ],
                ),
              ),

              // Mockup In-App Content (changes with slide)
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildMockupContent(currentPage),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMockupContent(int index) {
    switch (index) {
      case 0:
        return const _MockupPassengerMap(key: ValueKey('map_screen'));
      case 1:
        return const _MockupRouteAndFare(key: ValueKey('fare_screen'));
      case 2:
      default:
        return const _MockupPaymentAndPila(key: ValueKey('payment_screen'));
    }
  }
}

// ---------------------------------------------------------------------------
// Screen 1 Mockup: Passenger Map Screen (Laoag City Streets & Tricycle Radar)
// ---------------------------------------------------------------------------
class _MockupPassengerMap extends StatelessWidget {
  const _MockupPassengerMap({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Vector Street Grid & Padsan River Painter
        Positioned.fill(
          child: CustomPaint(
            painter: _LaoagMapPainter(),
          ),
        ),

        // Floating Search Bar: "Where to in Laoag?"
        Positioned(
          top: 8,
          left: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF007A37),
                  size: 15,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Where to in Laoag?',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mic_none_rounded,
                    color: Color(0xFFD97706),
                    size: 11,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Passenger Location Pin (Pulsing Green)
        Positioned(
          left: 110,
          top: 145,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Laoag Plaza',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF007A37).withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF007A37),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 3 Scattered Tricycles on Duty (Emerald & Gold)
        const Positioned(
          left: 45,
          top: 95,
          child: _TricyclePin(label: '#04'),
        ),
        const Positioned(
          right: 35,
          top: 125,
          child: _TricyclePin(label: '#12'),
        ),
        const Positioned(
          left: 70,
          bottom: 50,
          child: _TricyclePin(label: '#07'),
        ),

        // Bottom Info Pill: Nearby Active Tricycles
        Positioned(
          bottom: 10,
          left: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF007A37),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    '5 Tricycles in Central Laoag',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F8EF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '~2 min away',
                    style: TextStyle(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF007A37),
                    ),
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
// Screen 2 Mockup: Route & Fare Selection Screen (Laoag Central -> MMSU)
// ---------------------------------------------------------------------------
class _MockupRouteAndFare extends StatelessWidget {
  const _MockupRouteAndFare({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Vector Map with Route Polyline
        Positioned.fill(
          child: CustomPaint(
            painter: _LaoagRoutePainter(),
          ),
        ),

        // Top Route Pill
        Positioned(
          top: 8,
          left: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF007A37),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(width: 1, height: 10, color: const Color(0xFFCBD5E1)),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Laoag Central Terminal',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        'MMSU Laoag Campus',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '2.4 km',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom Fare Option Cards
        Positioned(
          bottom: 8,
          left: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Option 1: Regular (Selected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F8EF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF007A37), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.electric_rickshaw_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pasada Regular',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              '3 mins away • City Ord.',
                              style: TextStyle(fontSize: 7.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      const Text(
                        '₱20.00',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF007A37),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),

                // Option 2: Discounted
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.school_rounded,
                        color: Color(0xFF64748B),
                        size: 13,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Student / Senior (20% Off)',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      Text(
                        '₱16.00',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
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
// Screen 3 Mockup: Payment & TODA Queue Screen
// ---------------------------------------------------------------------------
class _MockupPaymentAndPila extends StatelessWidget {
  const _MockupPaymentAndPila({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          const Row(
            children: [
              Icon(Icons.arrow_back_ios_rounded, size: 10, color: Color(0xFF64748B)),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Choose Payment Method',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Tile 1: Cash (Selected)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8EF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF007A37), width: 1.2),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Color(0xFF007A37),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.payments_rounded, color: Colors.white, size: 12),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cash Payment',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Pay driver directly upon dropoff',
                        style: TextStyle(fontSize: 7.5, color: Color(0xFF007A37)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle_rounded, color: Color(0xFF007A37), size: 14),
              ],
            ),
          ),
          const SizedBox(height: 7),

          // Tile 2: Maya / GCash QR Ph
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 12),
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
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Scan BSP QR code on vehicle',
                        style: TextStyle(fontSize: 7.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 14),
              ],
            ),
          ),
          const Spacer(),

          // TODA Digital Pila Guarantee Card
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.shield_rounded, color: Colors.white, size: 13),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Laoag TODA Digital Pila',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF92400E),
                        ),
                      ),
                      Text(
                        'Driver Ernesto Corpuz assigned • Pila #01',
                        style: TextStyle(fontSize: 7.2, color: Color(0xFFB45309)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Mini Confirm Button
          Container(
            width: double.infinity,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF007A37),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Book Now',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper Widgets & Custom Painters for Map Mockup
// ---------------------------------------------------------------------------
class _TricyclePin extends StatelessWidget {
  final String label;

  const _TricyclePin({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.electric_rickshaw_rounded,
            color: Colors.white,
            size: 10,
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 7,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _LaoagMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFF1F5F9);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // River (Padsan River)
    final riverPaint = Paint()
      ..color = const Color(0xFFBAE6FD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    final riverPath = Path()
      ..moveTo(0, size.height * 0.82)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.72,
        size.width,
        size.height * 0.88,
      );
    canvas.drawPath(riverPath, riverPaint);

    // Park (Laoag Plaza Park)
    final parkPaint = Paint()..color = const Color(0xFFDCFCE7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.35,
          size.height * 0.42,
          size.width * 0.36,
          size.height * 0.18,
        ),
        const Radius.circular(8),
      ),
      parkPaint,
    );

    // Streets (Rizal St, J.P. Rizal St, Gilbert Bridge)
    final streetPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    final borderPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    void drawRoad(Path p) {
      canvas.drawPath(p, borderPaint);
      canvas.drawPath(p, streetPaint);
    }

    // Horizontal Streets
    final h1 = Path()
      ..moveTo(0, size.height * 0.28)
      ..lineTo(size.width, size.height * 0.28);
    drawRoad(h1);

    final h2 = Path()
      ..moveTo(0, size.height * 0.62)
      ..lineTo(size.width, size.height * 0.62);
    drawRoad(h2);

    // Vertical Streets
    final v1 = Path()
      ..moveTo(size.width * 0.26, 0)
      ..lineTo(size.width * 0.26, size.height);
    drawRoad(v1);

    final v2 = Path()
      ..moveTo(size.width * 0.74, 0)
      ..lineTo(size.width * 0.74, size.height);
    drawRoad(v2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LaoagRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Underlying map
    _LaoagMapPainter().paint(canvas, size);

    // Green Route Polyline
    final routeBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final routePaint = Paint()
      ..color = const Color(0xFF007A37)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final routePath = Path()
      ..moveTo(size.width * 0.26, size.height * 0.28)
      ..lineTo(size.width * 0.26, size.height * 0.62)
      ..lineTo(size.width * 0.74, size.height * 0.62)
      ..lineTo(size.width * 0.74, size.height * 0.45);

    canvas.drawPath(routePath, routeBorder);
    canvas.drawPath(routePath, routePaint);

    // Start Pin (Central Terminal)
    final startPaint = Paint()..color = const Color(0xFF007A37);
    canvas.drawCircle(
      Offset(size.width * 0.26, size.height * 0.28),
      6,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(Offset(size.width * 0.26, size.height * 0.28), 4, startPaint);

    // End Pin (MMSU)
    final endPaint = Paint()..color = const Color(0xFFF59E0B);
    canvas.drawCircle(
      Offset(size.width * 0.74, size.height * 0.45),
      6,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(Offset(size.width * 0.74, size.height * 0.45), 4, endPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
