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
  static const _screenAssets = <String>[
    'assets/screens/walkthrough_1.png',
    'assets/screens/walkthrough_2.png',
    'assets/screens/walkthrough_3.png',
  ];

  static const _screenSemantics = <Map<String, String>>[
    {
      'title': 'Welcome to PasadaNorte - Your Journey, Your Way',
      'subtitle':
          "Get ready to experience hassle-free transportation. We've got everything you need to travel with ease. Let's get started!",
    },
    {
      'title': 'Choose Your Ride - Tailored to Your Needs',
      'subtitle':
          'Select your preferred mode of transportation - motorbike / scooter, or car - and order a ride with just a few taps.',
    },
    {
      'title': 'Secure Payments & Seamless Transactions',
      'subtitle':
          'Say hello to convenience payments. Pay for your rides securely using Cash, Maya, GCash QR Ph, or TODA terminal digital dispatch.',
    },
  ];

  final PageController _controller = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    // Warm up Android permissions without blocking
    AndroidPermissionsService.getSavedState();
  }

  @override
  void dispose() {
    _controller.dispose();
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

  void _next() {
    if (_page == _screenAssets.length - 1) {
      _handleNavigation(startInRegisterMode: true);
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF08C76A),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // PageView displaying high-fidelity PasadaNorte Figma artboards
            PageView.builder(
              controller: _controller,
              itemCount: _screenAssets.length,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (context, index) {
                final semantics = _screenSemantics[index];
                return Semantics(
                  container: true,
                  label: '${semantics['title']!}. ${semantics['subtitle']!}',
                  child: _DesignScreen(assetName: _screenAssets[index]),
                );
              },
            ),

            // Responsive Action Regions mapped to the 430x932 Figma artboard
            if (_page < _screenAssets.length - 1) ...[
              // Skip Button Region (Left Pill)
              _ActionRegion(
                semanticsLabel: 'Skip onboarding',
                left: 24 / 430,
                bottom: 37 / 932,
                width: 183 / 430,
                height: 56 / 932,
                onTap: () => _handleNavigation(startInRegisterMode: false),
              ),
              // Continue Button Region (Right Pill)
              _ActionRegion(
                semanticsLabel: 'Continue',
                left: 223 / 430,
                bottom: 37 / 932,
                width: 183 / 430,
                height: 56 / 932,
                onTap: _next,
              ),
            ] else
              // Full-Width "Let's Get Started" Button Region
              _ActionRegion(
                semanticsLabel: "Let's get started",
                left: 24 / 430,
                bottom: 37 / 932,
                width: 382 / 430,
                height: 56 / 932,
                onTap: () => _handleNavigation(startInRegisterMode: true),
              ),
          ],
        ),
      ),
    );
  }
}

class _DesignScreen extends StatelessWidget {
  const _DesignScreen({required this.assetName});

  final String assetName;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Image.asset(
        assetName,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
        excludeFromSemantics: true,
      ),
    );
  }
}

class _ActionRegion extends StatelessWidget {
  const _ActionRegion({
    required this.semanticsLabel,
    required this.left,
    required this.bottom,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final String semanticsLabel;
  final double left;
  final double bottom;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned(
                left: constraints.maxWidth * left,
                bottom: constraints.maxHeight * bottom,
                width: constraints.maxWidth * width,
                height: constraints.maxHeight * height,
                child: Semantics(
                  button: true,
                  label: semanticsLabel,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
