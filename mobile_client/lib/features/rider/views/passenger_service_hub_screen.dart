import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/session_cache_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/views/welcome_onboarding_screen.dart';
import '../../fare/services/fare_calculator_service.dart';
import 'passenger_account_screen.dart';
import 'passenger_activity_screen.dart';
import 'rider_map_booking_screen.dart';

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
  static const String _savedAddressesKey = 'pasada_saved_addresses_v1';
  late int _currentIndex;
  List<Map<String, dynamic>> _savedAddresses = [];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    _loadSavedAddresses();
  }

  Future<void> _loadSavedAddresses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_savedAddressesKey) ?? const [];
      final parsed = raw
          .map((e) => Map<String, dynamic>.from(jsonDecode(e) as Map))
          .toList();
      if (!mounted) return;
      setState(() => _savedAddresses = parsed);
    } catch (_) {}
  }

  Future<void> _persistSavedAddresses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _savedAddressesKey,
        _savedAddresses.map((e) => jsonEncode(e)).toList(),
      );
    } catch (_) {}
  }

  IconData _iconForLabel(String label) {
    final l = label.toLowerCase();
    if (l.contains('home')) return Icons.home_rounded;
    if (l.contains('school') || l.contains('campus') || l.contains('univ')) {
      return Icons.school_rounded;
    }
    if (l.contains('work') || l.contains('office')) {
      return Icons.work_rounded;
    }
    return Icons.bookmark_rounded;
  }

  Future<void> _openAddAddressSheet() async {
    String selectedCategory = 'Home';
    final customLabelCtrl = TextEditingController();
    final searchCtrl = TextEditingController();
    Timer? debounce;
    bool isSearching = false;
    List<LocationPoint> results = const [
      LocationPoint(
        name: 'Laoag City Public Market, Brgy. 11 Sta. Balbina, Laoag',
        latitude: 18.1972,
        longitude: 120.5925,
      ),
      LocationPoint(
        name: 'MMSU CIT / CTE Campus, P. Gomez St, Laoag City',
        latitude: 18.1950,
        longitude: 120.5970,
      ),
      LocationPoint(
        name: 'Provincial Capitol & Aurora Park, Laoag City',
        latitude: 18.1960,
        longitude: 120.5920,
      ),
      LocationPoint(
        name: 'Northwestern University (NWU), Airport Rd, Laoag',
        latitude: 18.2020,
        longitude: 120.5870,
      ),
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          void onSearchChanged(String val) {
            debounce?.cancel();
            if (val.trim().isEmpty) return;
            debounce = Timer(const Duration(milliseconds: 350), () async {
              setSheetState(() => isSearching = true);
              final found = await LocationService.searchPlacesInLaoag(val);
              if (!ctx.mounted) return;
              setSheetState(() {
                isSearching = false;
                results = found;
              });
            });
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              height: MediaQuery.of(ctx).size.height * 0.78,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add New Saved Address',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primarySlate,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Home', 'School', 'Work', 'Other'].map((cat) {
                      final active = selectedCategory == cat;
                      return ChoiceChip(
                        avatar: Icon(
                          _iconForLabel(cat),
                          size: 16,
                          color: active ? Colors.white : AppTheme.primarySlate,
                        ),
                        label: Text(cat),
                        selected: active,
                        selectedColor: AppTheme.accentEmerald,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.white : AppTheme.primarySlate,
                        ),
                        onSelected: (_) =>
                            setSheetState(() => selectedCategory = cat),
                      );
                    }).toList(),
                  ),
                  if (selectedCategory == 'Other') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: customLabelCtrl,
                      decoration: InputDecoration(
                        hintText: 'Custom label (e.g., Gym, Church, Market)',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchCtrl,
                    onChanged: onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search street, barangay, or landmark in Laoag...',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppTheme.accentEmerald,
                      ),
                      suffixIcon: isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: results.isEmpty
                        ? Center(
                            child: Text(
                              'No matching places found in Laoag.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          )
                        : ListView.separated(
                            itemCount: results.length,
                            separatorBuilder: (_, __) =>
                                Divider(height: 1, color: Colors.grey.shade200),
                            itemBuilder: (_, idx) {
                              final place = results[idx];
                              return ListTile(
                                leading: const Icon(
                                  Icons.location_on_outlined,
                                  color: AppTheme.accentEmerald,
                                ),
                                title: Text(
                                  place.name.split(', ').first,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  place.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                onTap: () async {
                                  final label = selectedCategory == 'Other' &&
                                          customLabelCtrl.text.trim().isNotEmpty
                                      ? customLabelCtrl.text.trim()
                                      : selectedCategory;
                                  setState(() {
                                    _savedAddresses.removeWhere((a) =>
                                        a['label'].toString().toLowerCase() ==
                                        label.toLowerCase());
                                    _savedAddresses.add({
                                      'label': label,
                                      'address': place.name,
                                      'lat': place.latitude,
                                      'lng': place.longitude,
                                    });
                                  });
                                  await _persistSavedAddresses();
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    debounce?.cancel();
    customLabelCtrl.dispose();
    searchCtrl.dispose();
  }

  void _returnToHome(BuildContext context) {
    unawaited(SessionCacheService.clearSession());
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeOnboardingScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (_currentIndex != 0) {
            setState(() => _currentIndex = 0);
          } else {
            _returnToHome(context);
          }
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
        return PassengerActivityScreen(fullName: widget.fullName);
      case 2:
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
        titleSpacing: 20,
        title: const Text(
          'PasadaNorte',
          style: TextStyle(
            color: AppTheme.primarySlate,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Greeting Banner
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
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${widget.fullName.split(' ').first}!',
                      style: const TextStyle(
                        fontSize: 22,
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
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Verified ${widget.lockedCategory.name.toUpperCase()} Fare Tier Active',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // QUICK "WHERE TO?" + SAVED ADDRESSES (Home, School, Work, Custom)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A0F172A),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search_rounded,
                              color: AppTheme.accentEmerald,
                              size: 21,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Where to?',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primarySlate,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F8EF),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Book Now',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.accentEmerald,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Saved Addresses',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF475569),
                          ),
                        ),
                        GestureDetector(
                          onTap: _openAddAddressSheet,
                          child: const Text(
                            '+ Add New Address',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.accentEmerald,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ..._savedAddresses.map((addr) {
                            final label = addr['label'].toString();
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  final point = LocationPoint(
                                    name: addr['address'].toString(),
                                    latitude: (addr['lat'] as num).toDouble(),
                                    longitude: (addr['lng'] as num).toDouble(),
                                  );
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => RiderMapBookingScreen(
                                        fullName: widget.fullName,
                                        lockedCategory: widget.lockedCategory,
                                        initialTripType: TripType.standard,
                                        initialDropoff: point,
                                      ),
                                    ),
                                  );
                                },
                                onLongPress: () async {
                                  setState(() {
                                    _savedAddresses.remove(addr);
                                  });
                                  await _persistSavedAddresses();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _iconForLabel(label),
                                        size: 16,
                                        color: AppTheme.accentEmerald,
                                      ),
                                      const SizedBox(width: 6),
                                      ConstrainedBox(
                                        constraints:
                                            const BoxConstraints(maxWidth: 140),
                                        child: Text(
                                          label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.primarySlate,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                          InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: _openAddAddressSheet,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F8EF),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: AppTheme.accentEmerald
                                        .withValues(alpha: 0.4)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_location_alt_outlined,
                                    size: 16,
                                    color: AppTheme.accentEmerald,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Add Address',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.accentEmerald,
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
                accentColor: AppTheme.accentEmerald,
                bgColor: const Color(0xFFE8F8EF),
                rateText: widget.lockedCategory == PassengerCategory.regular
                    ? '₱${config.regularFirstKmFare.toStringAsFixed(0)} 1st km + ₱${config.succeedingKmRate.toStringAsFixed(0)}/km'
                    : '₱${config.discountedFirstKmFare.toStringAsFixed(0)} Discounted 1st km + 20% off',
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

              const SizedBox(height: 16),

              // OPTION 2: PA-DELIVER (ERRAND / PARCEL DELIVERY)
              _buildServiceCard(
                context: context,
                badge: 'PARCEL & MARKET ERRAND',
                title: 'PasaDeliver (Padala / Pabili)',
                subtitle:
                    'Send or receive documents, food, or public market packages with verified TODA dispatch and live GPS tracking.',
                icon: Icons.local_shipping_rounded,
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
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: accentColor, size: 28),
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
