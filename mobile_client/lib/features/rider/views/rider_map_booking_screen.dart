import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/views/welcome_onboarding_screen.dart';
import '../../fare/services/fare_calculator_service.dart';
import 'bill_summary_checkout_screen.dart';

class RiderMapBookingScreen extends StatefulWidget {
  final String fullName;
  final PassengerCategory lockedCategory;
  final TripType initialTripType;
  final LocationPoint? initialDropoff;

  const RiderMapBookingScreen({
    super.key,
    required this.fullName,
    this.lockedCategory = PassengerCategory.regular,
    this.initialTripType = TripType.standard,
    this.initialDropoff,
  });

  @override
  State<RiderMapBookingScreen> createState() => _RiderMapBookingScreenState();
}

class _RiderMapBookingScreenState extends State<RiderMapBookingScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _deliveryNotesController = TextEditingController();

  // Pickup is automatically the user's live GPS location; dropoff starts as null
  // so no destination is ever hardcoded or predicted for the passenger.
  LocationPoint _pickupPoint = LocationService.cachedUserHomeLocation;
  LocationPoint? _dropoffPoint;
  late PassengerCategory _lockedCategory;
  late TripType _selectedTripType;

  FareBreakdown? _fareBreakdown;
  List<LatLng> _routePolyline = [];
  int _estimatedDurationMinutes = 5;
  bool _isRouting = false;
  bool _isHybridSatellite = false;

  void _returnToPasadaNorteHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeOnboardingScreen()),
      (route) => false,
    );
  }

  @override
  void initState() {
    super.initState();
    _lockedCategory = widget.lockedCategory;
    _selectedTripType = widget.initialTripType;
    _dropoffPoint = widget.initialDropoff;
    // Automatically pinpoint live GPS pickup location on map open
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _useCurrentGpsForPickup(silent: true);
      if (mounted && _dropoffPoint != null) {
        _updateRouteAndFare();
      }
    });
  }

  @override
  void dispose() {
    _deliveryNotesController.dispose();
    super.dispose();
  }

  Future<void> _updateRouteAndFare() async {
    final dropoff = _dropoffPoint;
    if (dropoff == null) {
      setState(() {
        _isRouting = false;
        _routePolyline = [];
        _fareBreakdown = null;
      });
      return;
    }

    final straightDist = LocationService.calculateDistanceInKm(
      _pickupPoint.latitude,
      _pickupPoint.longitude,
      dropoff.latitude,
      dropoff.longitude,
    );

    setState(() {
      _isRouting = true;
      _fareBreakdown = FareCalculatorService.calculateFare(
        distanceKm: straightDist,
        category: _lockedCategory,
        tripType: _selectedTripType,
      );
    });

    final route = await LocationService.fetchRoadRoute(_pickupPoint, dropoff);
    if (!mounted) return;

    setState(() {
      _isRouting = false;
      _routePolyline = route.polylinePoints;
      _estimatedDurationMinutes = route.durationMinutes;
      _fareBreakdown = FareCalculatorService.calculateFare(
        distanceKm: route.distanceKm,
        category: _lockedCategory,
        tripType: _selectedTripType,
      );
    });

    _fitRouteOnMap();
  }

  void _fitRouteOnMap() {
    final dropoff = _dropoffPoint;
    if (dropoff == null) return;
    try {
      final points = _routePolyline.length >= 2
          ? _routePolyline
          : [_pickupPoint.latLng, dropoff.latLng];
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.fromLTRB(56, 110, 56, 120),
          maxZoom: 16.5,
        ),
      );
    } catch (_) {
      _mapController.move(dropoff.latLng, 15.5);
    }
  }

  Future<void> _onMapTapped(TapPosition tapPosition, LatLng point) async {
    final tempName =
        'Pinned Destination (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})...';

    setState(() {
      _dropoffPoint = LocationPoint(
        latitude: point.latitude,
        longitude: point.longitude,
        name: tempName,
        zoneCode: 'PIN',
      );
    });

    _updateRouteAndFare();

    final streetName = await LocationService.reverseGeocodePoint(
      point.latitude,
      point.longitude,
    );
    if (!mounted) return;

    setState(() {
      _dropoffPoint = LocationPoint(
        latitude: point.latitude,
        longitude: point.longitude,
        name: streetName,
        zoneCode: 'PIN',
      );
    });
  }

  Future<void> _useCurrentGpsForPickup({bool silent = false}) async {
    // 1. Immediately snap/recenter map camera to user's known coordinates with zero lag
    _mapController.move(_pickupPoint.latLng, 16.5);

    if (!silent && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
          }

    // 2. Fetch fresh hardware GPS fix in the background to ensure high precision
    try {
      final gpsPoint = await LocationService.warmUpDeviceGpsLocation();
      if (!mounted) return;
      if (gpsPoint.latitude != _pickupPoint.latitude ||
          gpsPoint.longitude != _pickupPoint.longitude) {
        setState(() {
          _pickupPoint = gpsPoint;
        });
        _mapController.move(_pickupPoint.latLng, 16.5);
        if (_dropoffPoint != null) {
          _updateRouteAndFare();
        }
      }
    } catch (_) {}
  }

  Future<void> _openDestinationSearchSheet() async {
    final selected = await showModalBottomSheet<LocationPoint>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LocationSearchSheet(
        initialQuery: _dropoffPoint?.name,
        currentLocationName: _pickupPoint.name,
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _dropoffPoint = selected;
      });
      _mapController.move(selected.latLng, 15.5);
      _updateRouteAndFare();
    }
  }

  void _clearSelectedDestination() {
    setState(() {
      _dropoffPoint = null;
      _routePolyline = [];
      _fareBreakdown = null;
    });
    _mapController.move(_pickupPoint.latLng, 16.0);
  }

  void _proceedToBillSummary() {
    if (_dropoffPoint == null || _fareBreakdown == null) {
      _openDestinationSearchSheet();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BillSummaryCheckoutScreen(
          fullName: widget.fullName,
          pickupPoint: _pickupPoint,
          dropoffPoint: _dropoffPoint!,
          routePolyline: _routePolyline.isNotEmpty
              ? _routePolyline
              : [_pickupPoint.latLng, _dropoffPoint!.latLng],
          durationMinutes: _estimatedDurationMinutes,
          fareBreakdown: _fareBreakdown!,
          deliveryNotes: _deliveryNotesController.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDelivery = _selectedTripType == TripType.pabiliPadala;
    final bool hasDestination = _dropoffPoint != null && _fareBreakdown != null;
    final double bottomInset = MediaQuery.of(context).padding.bottom;
    final double bottomSheetHeight = bottomInset +
        152.0 +
        (isDelivery ? 54.0 : 0.0) +
        (hasDestination ? 66.0 : 0.0);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Full-Bleed Interactive Google Map with User Blue Halo Dot
          Positioned.fill(
            bottom: bottomSheetHeight - 20.0,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _pickupPoint.latLng,
                initialZoom: 16.0,
                onTap: _onMapTapped,
              ),
              children: [
                TileLayer(
                  urlTemplate: _isHybridSatellite
                      ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
                      : 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                  userAgentPackageName: 'ph.laoag.pasadanorte',
                ),
                if (hasDestination && _routePolyline.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePolyline,
                        strokeWidth: 5.0,
                        color: const Color(0xFF1D8FF2),
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    // User's live GPS location: translucent blue accuracy halo + white-bordered blue dot
                    Marker(
                      point: _pickupPoint.latLng,
                      width: 110,
                      height: 110,
                      child: Semantics(
                        label: 'Your current location: ${_pickupPoint.name}',
                        child: Center(
                          child: Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.24),
                            ),
                            child: Center(
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0A84FF),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 5.5),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Only show destination marker AFTER passenger explicitly picks a destination
                    if (_dropoffPoint != null)
                      Marker(
                        point: _dropoffPoint!.latLng,
                        width: 48,
                        height: 48,
                        child: Semantics(
                          label: 'Destination location: ${_dropoffPoint!.name}',
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 6),
                              ],
                            ),
                            child: const Icon(Icons.location_on, color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Floating Top Bar (Back Button + Satellite Toggle + Admin Portal)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildFloatingCircleButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    tooltip: 'Back to Service Selection',
                    onTap: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        _returnToPasadaNorteHome();
                      }
                    },
                  ),
                  Row(
                    children: [
                      if (_isRouting)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                          ),
                          child: const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          ),
                        ),
                      _buildFloatingCircleButton(
                        icon: _isHybridSatellite ? Icons.map_rounded : Icons.satellite_alt_rounded,
                        tooltip: 'Toggle Google Roadmap / Satellite',
                        onTap: () => setState(() => _isHybridSatellite = !_isHybridSatellite),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 3. Bottom-Right Circular Re-Center GPS Location Button (Floats dynamically above Bottom Sheet)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            right: 18,
            bottom: bottomSheetHeight + 14.0,
            child: Tooltip(
              message: 'Recenter on my GPS location',
              child: Semantics(
                button: true,
                label: 'Recenter map on current GPS location',
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 5,
                  shadowColor: Colors.black26,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _useCurrentGpsForPickup(silent: false),
                    child: const SizedBox(
                      width: 52,
                      height: 52,
                      child: Center(
                        child: Icon(
                          Icons.my_location_rounded,
                          size: 24,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 4. Clean Bottom Sheet ("Where to?" Search Bar + Optional Book Ride Button Once Selected)
          Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragEnd: (details) {
                // Swiping up opens the full "Where do you want to go?" destination search sheet (Image 2)
                if ((details.primaryVelocity ?? 0) < -60) {
                  _openDestinationSearchSheet();
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 34),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4)),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top drag handle line with swipe up & tap activation
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _openDestinationSearchSheet,
                        onVerticalDragEnd: (details) {
                          if ((details.primaryVelocity ?? 0) < -60) {
                            _openDestinationSearchSheet();
                          }
                        },
                        child: Semantics(
                          button: true,
                          label: 'Expand destination search',
                          hint: 'Double tap or swipe up to open destination search',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Container(
                                width: 44,
                                height: 4.5,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                    // Clean "Where to?" Pill (Matching Reference Screenshot 1 — No Hardcoded Destination)
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _openDestinationSearchSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F3F5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE5E7EB),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.search_rounded,
                                size: 22,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                _dropoffPoint == null
                                    ? (isDelivery ? 'Where to deliver?' : 'Where to?')
                                    : _dropoffPoint!.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: _dropoffPoint == null
                                      ? FontWeight.w700
                                      : FontWeight.w800,
                                  color: const Color(0xFF1F2937),
                                ),
                              ),
                            ),
                            if (_dropoffPoint != null)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Clear Destination',
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 20,
                                  color: Color(0xFF64748B),
                                ),
                                onPressed: _clearSelectedDestination,
                              ),
                          ],
                        ),
                      ),
                    ),

                    if (isDelivery) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _deliveryNotesController,
                        decoration: const InputDecoration(
                          hintText:
                              'Item description / Recipient name & contact (e.g. 1 box documents)...',
                          prefixIcon: Icon(Icons.inventory_2_outlined, size: 18),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ],

                    // Show "Book Ride" CTA only after the passenger chooses a destination
                    if (hasDestination) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _proceedToBillSummary,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDelivery
                                ? const Color(0xFFD97706)
                                : AppTheme.accentEmerald,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isDelivery ? 'Book Pa-Deliver' : 'Book Ride',
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '₱${_fareBreakdown!.finalFare.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildFloatingCircleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 4,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Icon(icon, size: 22, color: AppTheme.primarySlate),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationSearchSheet extends StatefulWidget {
  final String? initialQuery;
  final String? currentLocationName;

  const _LocationSearchSheet({
    this.initialQuery,
    this.currentLocationName,
  });

  @override
  State<_LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<_LocationSearchSheet> {
  static const String _recentPrefsKey = 'pasada_recent_destinations_v1';
  static const String _bookmarksPrefsKey = 'pasada_bookmarked_destinations_v1';

  static const List<LocationPoint> _suggestedLaoagPlaces = [
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
      name: 'Robinsons Place Ilocos, San Nicolas, Ilocos Norte',
      latitude: 18.1845,
      longitude: 120.5912,
    ),
    LocationPoint(
      name: 'Laoag Sinking Bell Tower & Plaza, J.P. Rizal St, Laoag',
      latitude: 18.1965,
      longitude: 120.5938,
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

  late final TextEditingController _searchController;
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;
  bool _isSearching = false;
  int _activeTabIndex = 0; // 0 = Recent, 1 = Suggested
  List<LocationPoint> _results = const [];
  List<LocationPoint> _recentPlaces = const [];
  List<Map<String, dynamic>> _savedAddresses = const [];
  Set<String> _bookmarkedNames = {};

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    _loadSavedPlaces();
    if (_searchController.text.trim().isNotEmpty) {
      _searchController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchController.text.length,
      );
      _performSearch(_searchController.text);
    }
  }

  Future<void> _loadSavedPlaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentRaw = prefs.getStringList(_recentPrefsKey) ?? const [];
      final bookmarksRaw = prefs.getStringList(_bookmarksPrefsKey) ?? const [];
      final savedAddrRaw = prefs.getStringList('pasada_saved_addresses_v1') ?? const [];
      final parsedRecent = <LocationPoint>[];
      for (final item in recentRaw) {
        final decoded = jsonDecode(item) as Map<String, dynamic>;
        parsedRecent.add(LocationPoint(
          name: decoded['name'].toString(),
          latitude: (decoded['lat'] as num).toDouble(),
          longitude: (decoded['lng'] as num).toDouble(),
        ));
      }
      final parsedSaved = savedAddrRaw
          .map((e) => Map<String, dynamic>.from(jsonDecode(e) as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _recentPlaces = parsedRecent;
        _savedAddresses = parsedSaved;
        _bookmarkedNames = bookmarksRaw.toSet();
        if (_recentPlaces.isEmpty) {
          _activeTabIndex = 1; // Show Suggested by default if no recent yet
        }
      });
    } catch (_) {}
  }

  Future<void> _selectPlace(LocationPoint place) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final updated = [
        place,
        ..._recentPlaces.where((p) => p.name != place.name),
      ].take(8).toList();
      await prefs.setStringList(
        _recentPrefsKey,
        updated
            .map((p) => jsonEncode({
                  'name': p.name,
                  'lat': p.latitude,
                  'lng': p.longitude,
                }))
            .toList(),
      );
    } catch (_) {}
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    Navigator.pop(context, place);
  }

  Future<void> _toggleBookmark(LocationPoint place) async {
    setState(() {
      if (_bookmarkedNames.contains(place.name)) {
        _bookmarkedNames.remove(place.name);
      } else {
        _bookmarkedNames.add(place.name);
      }
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_bookmarksPrefsKey, _bookmarkedNames.toList());
    } catch (_) {}
  }

  void _performSearch(String val) async {
    if (val.trim().isEmpty) return;
    setState(() => _isSearching = true);
    final found = await LocationService.searchPlacesInLaoag(val);
    if (!mounted) return;
    setState(() {
      _isSearching = false;
      _results = found;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String val) {
    _debounce?.cancel();
    if (val.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _results = const [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _performSearch(val);
    });
  }

  Widget _buildQuickShortcutPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFF0F172A),
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceTile(LocationPoint place) {
    final distKm = LocationService.calculateDistanceInKm(
      LocationService.cachedUserHomeLocation.latitude,
      LocationService.cachedUserHomeLocation.longitude,
      place.latitude,
      place.longitude,
    );
    final parts = place.name.split(', ');
    final title = parts.first;
    final subtitle =
        parts.length > 1 ? parts.sublist(1).join(', ') : place.name;
    final isBookmarked = _bookmarkedNames.contains(place.name);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        ),
        child: const Icon(
          Icons.location_on_outlined,
          color: AppTheme.primarySlate,
          size: 20,
        ),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14.5,
          color: AppTheme.primarySlate,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${distKm.toStringAsFixed(1)} km',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            icon: Icon(
              isBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              size: 20,
              color: isBookmarked
                  ? AppTheme.accentEmerald
                  : const Color(0xFF475569),
            ),
            onPressed: () => _toggleBookmark(place),
          ),
        ],
      ),
      onTap: () => _selectPlace(place),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasQuery = _searchController.text.trim().isNotEmpty;
    final List<LocationPoint> activeList =
        _activeTabIndex == 0 ? _recentPlaces : _suggestedLaoagPlaces;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(context),
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) > 80) {
                Navigator.pop(context);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 24),
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  'Where do you want to go?',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primarySlate,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Top Dual Input Card + Quick Pills (Image 2 style)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: AppTheme.accentEmerald,
                        size: 19,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          (widget.currentLocationName != null &&
                                  widget.currentLocationName!.trim().isNotEmpty)
                              ? widget.currentLocationName!
                              : 'Your current location',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primarySlate,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        autofocus: true,
                        onChanged: _onQueryChanged,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primarySlate,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Where to?',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(
                            Icons.location_on_rounded,
                            color: AppTheme.cancelRed,
                            size: 19,
                          ),
                          suffixIcon: _isSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                )
                              : (hasQuery
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        _onQueryChanged('');
                                      },
                                    )
                                  : null),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () {
                        _searchController.clear();
                        _onQueryChanged('');
                        _searchFocusNode.requestFocus();
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.accentEmerald,
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: AppTheme.accentEmerald,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildQuickShortcutPill(
                        icon: Icons.map_outlined,
                        iconColor: AppTheme.accentEmerald,
                        label: 'Select from map',
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          Navigator.pop(context);
                        },
                      ),
                      ..._savedAddresses.map((addr) {
                        final label = addr['label']?.toString() ?? 'Saved';
                        final lower = label.toLowerCase();
                        final IconData pillIcon = lower.contains('home')
                            ? Icons.home_outlined
                            : (lower.contains('school') || lower.contains('univ'))
                                ? Icons.school_outlined
                                : (lower.contains('work') || lower.contains('office'))
                                    ? Icons.work_outline_rounded
                                    : Icons.location_on_outlined;
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _buildQuickShortcutPill(
                            icon: pillIcon,
                            label: label,
                            onTap: () => _selectPlace(
                              LocationPoint(
                                name: addr['address']?.toString() ?? label,
                                latitude: (addr['lat'] as num).toDouble(),
                                longitude: (addr['lng'] as num).toDouble(),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (!hasQuery) ...[
            const SizedBox(height: 14),
            // Recent / Suggested Segmented Pill Bar
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTabIndex = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _activeTabIndex == 0
                              ? AppTheme.accentEmerald
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Recent',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: _activeTabIndex == 0
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTabIndex = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _activeTabIndex == 1
                              ? AppTheme.accentEmerald
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Suggested',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: _activeTabIndex == 1
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),
          Expanded(
            child: hasQuery
                ? (_results.isEmpty && !_isSearching
                    ? Center(
                        child: Text(
                          'No matching places found. Try another street name or tap "Select from map".',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (context, index) =>
                            _buildPlaceTile(_results[index]),
                      ))
                : (activeList.isEmpty
                    ? Center(
                        child: Text(
                          'No recent destinations yet. Switch to Suggested or type a place above.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: activeList.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (context, index) =>
                            _buildPlaceTile(activeList[index]),
                      )),
          ),
        ],
      ),
    );
  }
}
