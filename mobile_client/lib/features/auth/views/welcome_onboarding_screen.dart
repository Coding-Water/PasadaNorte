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

  final List<Map<String, dynamic>> _slides = [
    {
      'icon': Icons.electric_rickshaw_rounded,
      'tag': 'LAOAG CITY MOBILITY',
      'title': 'Everyday Tricycle Rides, Made Effortless.',
      'description':
          'PasadaNorte connects commuters, students, tourists, and TODA tricycle drivers across Laoag City with transparent city fares and organized terminal queues.',
      'pills': [
        'Serving 10 Laoag City Zones (Central Terminal, MMSU, INCAT, Plaza, LCGH, Capitol, NWU, Robinsons, Gilbert Bridge, Airport)',
        'Built for Commuters, Visiting Tourists & TODA Drivers',
      ],
    },
    {
      'icon': Icons.route_rounded,
      'tag': 'FAIR & TRANSPARENT PRICING',
      'title': 'Approved City Fares & Smart Digital Pila',
      'description':
          'No more haggling. Your fare is calculated upfront from the actual GPS road route under City Ordinance No. 2023-005 & Oct 2026 SP schedules while dispatching fairly from the nearest TODA queue.',
      'pills': [
        '₱20.00 regular / ₱15.00 discounted 1st km (City Ord. 2023-005) or Oct 2026 SP ₱25/₱20',
        '20% statutory discount on succeeding km (LTFRB MC No. 2025-10)',
        'Zero-touch GPS terminal queueing ("Digital Pila")',
      ],
    },
    {
      'icon': Icons.verified_user_rounded,
      'tag': 'TRUST & DATA PRIVACY',
      'title': '1:1 Verified Accounts & Privacy Heatmaps',
      'description':
          'To protect drivers from fake bookings and keep rides safe, new accounts complete a quick 1:1 face-to-ID check backed by TODA/MINC administrator review.',
      'pills': [
        'RA 10173 & NPC Circular No. 2023-03 informed consent & AES-256 templates',
        'Auto-approved images purged immediately; admin staging <= 72 hours',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndPromptAndroidPermissions();
    });
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

  void _goToAuth({required bool startInRegisterMode}) {
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
    return Scaffold(
      backgroundColor: AppTheme.primarySlate,
      body: Column(
        children: [
          // Top Dark Hero Section (Uber / Grab Super-App Style)
          Expanded(
            flex: 5,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                child: Column(
                  children: [
                    // Top Brand Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.accentEmerald,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.electric_rickshaw_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PasadaNorte',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                Text(
                                  'Laoag City • Ilocos Norte',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _checkAndPromptAndroidPermissions(forceShowAll: true),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _permState.allGranted
                                      ? AppTheme.accentEmerald.withOpacity(0.22)
                                      : Colors.amber.withOpacity(0.22),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _permState.allGranted
                                          ? Icons.verified_user_rounded
                                          : Icons.tune_rounded,
                                      color: _permState.allGranted
                                          ? const Color(0xFF4ADE80)
                                          : Colors.amber,
                                      size: 13,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _permState.allGranted
                                          ? '4/4 Perms Active'
                                          : 'Permissions',
                                      style: TextStyle(
                                        color: _permState.allGranted
                                            ? const Color(0xFF4ADE80)
                                            : Colors.amber,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => _goToAuth(startInRegisterMode: false),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.white.withOpacity(0.1),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text(
                                'Skip',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Hero Slide Content
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _slides.length,
                        onPageChanged: (idx) => setState(() => _currentPage = idx),
                        itemBuilder: (context, index) {
                          final slide = _slides[index];
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.accentEmerald,
                                      AppTheme.accentEmerald.withOpacity(0.65),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accentEmerald.withOpacity(0.35),
                                      blurRadius: 24,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  slide['icon'] as IconData,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentEmerald.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  slide['tag'] as String,
                                  style: const TextStyle(
                                    color: Color(0xFF4ADE80),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                slide['title'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 27,
                                  fontWeight: FontWeight.w800,
                                  height: 1.18,
                                  letterSpacing: -0.6,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                slide['description'] as String,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom White Sheet (Clean Grab / Uber Action Card)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Feature Checklist Pills for Active Slide
                ...((_slides[_currentPage]['pills'] as List<String>).map((pill) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.accentEmerald,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            pill,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primarySlate,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                })),

                const SizedBox(height: 14),

                // Progress Dots
                Row(
                  children: List.generate(
                    _slides.length,
                    (idx) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.only(right: 6),
                      width: _currentPage == idx ? 26 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == idx
                            ? AppTheme.accentEmerald
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Primary CTA Button (Grab Green)
                ElevatedButton(
                  onPressed: () {
                    if (_currentPage < _slides.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                      );
                    } else {
                      _goToAuth(startInRegisterMode: true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentEmerald,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    _currentPage < _slides.length - 1
                        ? 'Continue'
                        : 'Create New Account',
                  ),
                ),
                const SizedBox(height: 10),

                // Secondary CTA Button (Uber Slate Outline)
                OutlinedButton(
                  onPressed: () => _goToAuth(startInRegisterMode: false),
                  child: const Text('Log In with Mobile Number'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
