import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/views/welcome_onboarding_screen.dart';
import '../../fare/services/fare_calculator_service.dart';
import 'bill_summary_checkout_screen.dart';

class RiderMapBookingScreen extends StatefulWidget {
  final String fullName;
  final PassengerCategory lockedCategory;
  final TripType initialTripType;

  const RiderMapBookingScreen({
    super.key,
    required this.fullName,
    this.lockedCategory = PassengerCategory.regular,
    this.initialTripType = TripType.standard,
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
    // Automatically pinpoint live GPS pickup location on map open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _useCurrentGpsForPickup(silent: true);
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
    try {
      final gpsPoint = await LocationService.warmUpDeviceGpsLocation();
      if (!mounted) return;
      setState(() {
        _pickupPoint = gpsPoint;
      });
      _mapController.move(_pickupPoint.latLng, 16.0);
      if (_dropoffPoint != null) {
        _updateRouteAndFare();
      }
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Centered on your GPS location: ${gpsPoint.name}'),
            backgroundColor: const Color(0xFF1D8FF2),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    } catch (_) {}

    if (!mounted) return;
    _mapController.move(_pickupPoint.latLng, 16.0);
  }

  Future<void> _openDestinationSearchSheet() async {
    final selected = await showModalBottomSheet<LocationPoint>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _LocationSearchSheet(),
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

    return Scaffold(
      body: Stack(
        children: [
          // 1. Full-Bleed Interactive Google Map with User Blue Halo Dot
          Positioned.fill(
            bottom: hasDestination ? 190 : 120,
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
                    // Only show destination marker AFTER passenger explicitly picks a destination
                    if (_dropoffPoint != null)
                      Marker(
                        point: _dropoffPoint!.latLng,
                        width: 48,
                        height: 48,
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

          // 3. Bottom-Right Circular Re-Center GPS Location Button (Readjusts to Accurate Position)
          Positioned(
            right: 18,
            bottom: (hasDestination ? (isDelivery ? 275 : 215) : (isDelivery ? 195 : 138)),
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

          // 4. Clean Bottom Sheet ("Where to?" Search Bar + Optional Book Ride Button Once Selected)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                    Center(
                      child: Container(
                        width: 44,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

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
        ],
      ),
    );
  }

  Widget _buildFloatingCircleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Icon(icon, size: 20, color: AppTheme.primarySlate),
        ),
      ),
    );
  }
}

class _LocationSearchSheet extends StatefulWidget {
  const _LocationSearchSheet();

  @override
  State<_LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<_LocationSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  // Never pre-populate or predict hardcoded destinations; start completely empty
  List<LocationPoint> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
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
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);
      final found = await LocationService.searchPlacesInLaoag(val);
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _results = found;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool hasQuery = _searchController.text.trim().isNotEmpty;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
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
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primarySlate,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dual Input Card (Your current location + Destination search field)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEEEEEE), width: 1.5),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        color: AppTheme.accentEmerald,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your current location',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primarySlate,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: Colors.grey.shade200),
                ),
                TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: _onQueryChanged,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primarySlate,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Where to?',
                    fillColor: const Color(0xFFFAFAFA),
                    prefixIcon: const Icon(
                      Icons.location_on_rounded,
                      color: AppTheme.cancelRed,
                      size: 20,
                    ),
                    suffixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
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
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: !hasQuery
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.travel_explore_rounded,
                          size: 46,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Type your destination above or close and tap directly on the map.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : (_results.isEmpty && !_isSearching
                    ? Center(
                        child: Text(
                          'No matching places found. Try another street name or tap directly on the map.',
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
                        itemBuilder: (context, index) {
                          final place = _results[index];
                          final distKm = LocationService.calculateDistanceInKm(
                            LocationService.cachedUserHomeLocation.latitude,
                            LocationService.cachedUserHomeLocation.longitude,
                            place.latitude,
                            place.longitude,
                          );
                          final parts = place.name.split(', ');
                          final title = parts.first;
                          final subtitle = parts.length > 1
                              ? parts.sublist(1).join(', ')
                              : place.name;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 4,
                            ),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.location_on_outlined,
                                color: AppTheme.primarySlate,
                                size: 22,
                              ),
                            ),
                            title: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: AppTheme.primarySlate,
                              ),
                            ),
                            subtitle: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            trailing: Text(
                              '${distKm.toStringAsFixed(1)} km',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primarySlate,
                              ),
                            ),
                            onTap: () => Navigator.pop(context, place),
                          );
                        },
                      )),
          ),
        ],
      ),
    );
  }
}
