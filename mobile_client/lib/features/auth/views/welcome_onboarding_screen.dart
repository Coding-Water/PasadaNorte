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

  // PasadaNorte Emerald Color Palette
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
          'Say hello to convenience payments. Pay for your rides securely using Cash, Maya, GCash QR Ph, or TODA terminal digital dispatch.',
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

    // White bottom sheet takes ~50% of the screen height
    final bottomSheetHeight = math.min(screenHeight * 0.50, 450.0);
    // Phone mockup width increased for a wider, immersive presentation
    final phoneWidth = math.min(screenWidth * 0.90, 400.0);
    // Phone mockup extends downward behind the white scooped curve
    final phoneHeight = math.min(screenHeight * 0.60, 540.0);

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
            // 1. Phone Mockup Layer (Top hero, submerged into the white container)
            Positioned(
              top: mediaQuery.padding.top + 8,
              left: (screenWidth - phoneWidth) / 2,
              width: phoneWidth,
              height: phoneHeight,
              child: _ImmersivePhoneMockup(
                currentPage: _currentPage,
              ),
            ),

            // 2. White Container with Downward Dipping Scoop Curve
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: bottomSheetHeight,
              child: ClipPath(
                clipper: const _WhiteScoopClipper(),
                child: Container(
                  color: Colors.white,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 48, 28, 24),
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

                          // Bottom Action Buttons (Skip & Continue on slides 1 & 2, Let's Get Started on slide 3)
                          if (_currentPage < _slides.length - 1)
                            Row(
                              children: [
                                // Skip Button (Soft Mint Capsule)
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
                                // Continue Button (Vibrant Emerald Capsule)
                                Expanded(
                                  child: SizedBox(
                                    height: 54,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        _pageController.nextPage(
                                          duration:
                                              const Duration(milliseconds: 300),
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
                                    borderRadius: BorderRadius.circular(27),
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
// White Scoop Clipper (Dips down smoothly in the center)
// ---------------------------------------------------------------------------
class _WhiteScoopClipper extends CustomClipper<Path> {
  const _WhiteScoopClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    // Boundary curve dips down in the center by ~30dp
    const curveDip = 30.0;

    // Top-left starts at y = 0
    path.moveTo(0, 0);
    // Smooth concave curve dipping down to (width/2, curveDip) at the center
    path.quadraticBezierTo(
      size.width / 2,
      curveDip * 2,
      size.width,
      0,
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
// Passenger App Screen Hero (Direct phone screenshot display without clipping)
// ---------------------------------------------------------------------------
class _ImmersivePhoneMockup extends StatelessWidget {
  final int currentPage;

  const _ImmersivePhoneMockup({required this.currentPage});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _buildScreenContent(currentPage),
    );
  }

  Widget _buildScreenContent(int index) {
    final assetNames = [
      'assets/images/walkthrough_1.png',
      'assets/images/walkthrough_2.png',
      'assets/images/walkthrough_3.png',
    ];

    return Transform.scale(
      scale: 1.06,
      alignment: Alignment.topCenter,
      child: Image.asset(
        assetNames[index],
        key: ValueKey(assetNames[index]),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
      ),
    );
  }
}
