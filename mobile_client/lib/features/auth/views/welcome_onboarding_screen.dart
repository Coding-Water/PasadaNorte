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

  // PasadaNorte Emerald & Joyride Color Palette
  static const Color _primaryGreen = Color(0xFF00C466);
  static const Color _mintBackground = Color(0xFFE8F8EF);
  static const Color _darkHeading = Color(0xFF212121);
  static const Color _subtitleGrey = Color(0xFF757575);
  static const Color _dotInactive = Color(0xFFE0E0E0);

  final List<Map<String, String>> _slides = [
    {
      'title': 'Welcome to PasadaNorte - Your\nJourney, Your Way',
      'subtitle':
          "Get ready to experience hassle-free transportation. We've got everything you need to travel with ease. Let's get started!",
    },
    {
      'title': 'Choose Your Ride -\nTailored to Your Needs',
      'subtitle':
          'Select your preferred mode of transportation - motorbike / scooter, or car - and order a ride with just a few taps.',
    },
    {
      'title': 'Secure Payments &\nSeamless Transactions',
      'subtitle':
          'Say hello to convenience payments. Pay for your rides securely using GoRide Wallet, PayPal, Google Pay, Apple Pay, card, and or cash.',
    },
  ];

  @override
  void initState() {
    super.initState();
    // Warm up Android permissions without blocking
    AndroidPermissionsService.getSavedState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleNavigation({required bool startInRegisterMode}) async {
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
    final screenWidth = mediaQuery.size.width;

    // Upward Dome Sheet height takes ~48-50% of the screen
    final bottomSheetHeight = math.min(screenHeight * 0.49, 440.0);
    // Phone mockup height extends down to overlap with the bottom sheet
    final phoneHeight = math.min(screenHeight * 0.54, 490.0);
    final phoneWidth = math.min(screenWidth * 0.86, 360.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _primaryGreen,
        body: Stack(
          children: [
            // 1. Phone Mockup Layer (Positioned high, wide, dipping into the bottom sheet)
            Positioned(
              top: mediaQuery.padding.top + 16,
              left: (screenWidth - phoneWidth) / 2,
              width: phoneWidth,
              height: phoneHeight,
              child: _ImmersiveJoyridePhone(
                currentPage: _currentPage,
              ),
            ),

            // 2. White Curved Dome Sheet (Arches UP in the center, overlapping the bottom of the phone)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: bottomSheetHeight,
              child: ClipPath(
                clipper: const _JoyrideWhiteDomeClipper(),
                child: Container(
                  color: Colors.white,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 42, 28, 20),
                      child: Column(
                        children: [
                          // PageView Content (Centered Title & Subtitle)
                          Expanded(
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: _slides.length,
                              onPageChanged: (idx) =>
                                  setState(() => _currentPage = idx),
                              itemBuilder: (context, index) {
                                final slide = _slides[index];
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      slide['title']!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 24,
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
                                        fontSize: 14,
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

                          // Indicator Dots (32dp wide active pill + 8dp circles)
                          Semantics(
                            label:
                                'Page ${_currentPage + 1} of ${_slides.length}',
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(_slides.length, (idx) {
                                final isActive = _currentPage == idx;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 4),
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

                          // Bottom Action Buttons (50/50 split on slides 1 & 2, full-width on slide 3)
                          if (_currentPage < _slides.length - 1)
                            Row(
                              children: [
                                // Skip Button (Soft Mint Capsule)
                                Expanded(
                                  child: SizedBox(
                                    height: 56,
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
                                              BorderRadius.circular(28),
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
                                // Continue Button (Vibrant Emerald Capsule)
                                Expanded(
                                  child: SizedBox(
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        _pageController.nextPage(
                                          duration:
                                              const Duration(milliseconds: 320),
                                          curve: Curves.easeOutCubic,
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _primaryGreen,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(28),
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
                              height: 56,
                              child: ElevatedButton(
                                onPressed: () => _handleNavigation(
                                  startInRegisterMode: true,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryGreen,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
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
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// White Dome Clipper (Arches UP in the center by 45dp, exactly like Joyride)
// ---------------------------------------------------------------------------
class _JoyrideWhiteDomeClipper extends CustomClipper<Path> {
  const _JoyrideWhiteDomeClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    const archRise = 42.0;

    // Start on the left edge at y = archRise
    path.moveTo(0, archRise);
    // Smooth convex quadratic curve reaching UP to y = 0 at the center
    path.quadraticBezierTo(
      size.width / 2,
      0,
      size.width,
      archRise,
    );
    // Complete the bottom rectangle
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ---------------------------------------------------------------------------
// Immersive Phone Chassis (Full-Bleed Screen Content inside iPhone Frame)
// ---------------------------------------------------------------------------
class _ImmersiveJoyridePhone extends StatelessWidget {
  final int currentPage;

  const _ImmersiveJoyridePhone({required this.currentPage});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141416), // Sleek black chassis
        borderRadius: BorderRadius.circular(42),
        border: Border.all(color: const Color(0xFF27272A), width: 3.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4.5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(38),
        child: Container(
          color: Colors.white,
          child: Stack(
            children: [
              // 1. Full-Bleed App Screen Image (NO phone inside phone, 100% clean UI)
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: _buildScreenContent(currentPage),
                ),
              ),

              // 2. Joyride iPhone Dynamic Island at Top
              Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 72,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E293B),
                            shape: BoxShape.circle,
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
      ),
    );
  }

  Widget _buildScreenContent(int index) {
    final assetNames = [
      'assets/images/walkthrough_1.png',
      'assets/images/walkthrough_2.png',
      'assets/images/walkthrough_3.png',
    ];

    return Image.asset(
      assetNames[index],
      key: ValueKey(assetNames[index]),
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
    );
  }
}
