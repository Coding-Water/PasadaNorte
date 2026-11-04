import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../admin/views/web_admin_portal_screen.dart';
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

  // Automatically default pickup to the passenger's real/home GPS location instead of Central Market
  LocationPoint _pickupPoint = LocationService.cachedUserHomeLocation;
  LocationPoint _dropoffPoint = LocationService.laoagLandmarks[1];
  late PassengerCategory _lockedCategory;
  late TripType _selectedTripType;

  late FareBreakdown _fareBreakdown;
  List<LatLng> _routePolyline = [];
  int _estimatedDurationMinutes = 5;
  bool _isRouting = false;
  bool _isHybridSatellite = false;
  bool _tapMapSetsDropoff = true;

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
    _routePolyline = [_pickupPoint.latLng, _dropoffPoint.latLng];
    _updateRouteAndFare();
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
    final straightDist = LocationService.calculateDistanceInKm(
      _pickupPoint.latitude,
      _pickupPoint.longitude,
      _dropoffPoint.latitude,
      _dropoffPoint.longitude,
    );

    setState(() {
      _isRouting = true;
      _fareBreakdown = FareCalculatorService.calculateFare(
        distanceKm: straightDist,
        category: _lockedCategory,
        tripType: _selectedTripType,
      );
    });

    final route = await LocationService.fetchRoadRoute(_pickupPoint, _dropoffPoint);
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
  }

  void _recalculateFareFromCurrentDistance() {
    setState(() {
      _fareBreakdown = FareCalculatorService.calculateFare(
        distanceKm: _fareBreakdown.distanceKm,
        category: _lockedCategory,
        tripType: _selectedTripType,
      );
    });
  }

  Future<void> _onMapTapped(TapPosition tapPosition, LatLng point) async {
    final tempName = _tapMapSetsDropoff
        ? 'Dropping pin (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})...'
        : 'Setting pickup (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})...';

    setState(() {
      if (_tapMapSetsDropoff) {
        _dropoffPoint = LocationPoint(
          latitude: point.latitude,
          longitude: point.longitude,
          name: tempName,
          zoneCode: 'PIN',
        );
      } else {
        _pickupPoint = LocationPoint(
          latitude: point.latitude,
          longitude: point.longitude,
          name: tempName,
          zoneCode: 'PIN',
        );
      }
    });

    _updateRouteAndFare();

    final streetName = await LocationService.reverseGeocodePoint(
      point.latitude,
      point.longitude,
    );
    if (!mounted) return;

    setState(() {
      if (_tapMapSetsDropoff) {
        _dropoffPoint = LocationPoint(
          latitude: point.latitude,
          longitude: point.longitude,
          name: streetName,
          zoneCode: 'PIN',
        );
      } else {
        _pickupPoint = LocationPoint(
          latitude: point.latitude,
          longitude: point.longitude,
          name: streetName,
          zoneCode: 'PIN',
        );
      }
    });
  }

  Future<void> _useCurrentGpsForPickup({bool silent = false}) async {
    try {
      final gpsPoint = await LocationService.warmUpDeviceGpsLocation();
      if (!mounted) return;
      setState(() {
        _pickupPoint = gpsPoint;
      });
      _mapController.move(_pickupPoint.latLng, 15.2);
      _updateRouteAndFare();
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pinpointed GPS Pickup: ${gpsPoint.name}'),
            backgroundColor: AppTheme.accentEmerald,
          ),
        );
      }
      return;
    } catch (_) {}

    if (!mounted || silent) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tap anywhere on the map or type any street to set your exact location.'),
      ),
    );
  }

  Future<void> _openFreeLocationSearchSheet({required bool isSelectingPickup}) async {
    final selected = await showModalBottomSheet<LocationPoint>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LocationSearchSheet(
        isSelectingPickup: isSelectingPickup,
        initialQuery: '',
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        if (isSelectingPickup) {
          _pickupPoint = selected;
        } else {
          _dropoffPoint = selected;
        }
      });
      _mapController.move(selected.latLng, 15.0);
      _updateRouteAndFare();
    }
  }

  void _proceedToBillSummary() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BillSummaryCheckoutScreen(
          fullName: widget.fullName,
          pickupPoint: _pickupPoint,
          dropoffPoint: _dropoffPoint,
          routePolyline: _routePolyline,
          durationMinutes: _estimatedDurationMinutes,
          fareBreakdown: _fareBreakdown,
          deliveryNotes: _deliveryNotesController.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDelivery = _selectedTripType == TripType.pabiliPadala;
    final centerLat = (_pickupPoint.latitude + _dropoffPoint.latitude) / 2;
    final centerLng = (_pickupPoint.longitude + _dropoffPoint.longitude) / 2;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Full-Bleed Interactive Google Map (Tap Anywhere to Drop Pin!)
          Positioned.fill(
            bottom: 240,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(centerLat, centerLng),
                initialZoom: 15.0,
                onTap: _onMapTapped,
              ),
              children: [
                TileLayer(
                  urlTemplate: _isHybridSatellite
                      ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
                      : 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                  userAgentPackageName: 'ph.laoag.pasadanorte',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePolyline,
                      strokeWidth: 5.0,
                      color: AppTheme.primarySlate,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _pickupPoint.latLng,
                      width: 48,
                      height: 48,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.accentEmerald,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                        ),
                        child: const Icon(Icons.my_location, color: Colors.white, size: 20),
                      ),
                    ),
                    Marker(
                      point: _dropoffPoint.latLng,
                      width: 48,
                      height: 48,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                        ),
                        child: const Icon(Icons.location_on, color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Floating Top Bar (Back to Service Hub + Locked Fare Badge + Satellite Toggle)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
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
                      const SizedBox(width: 8),
                      _buildFloatingCircleButton(
                        icon: _isHybridSatellite ? Icons.map_rounded : Icons.satellite_alt_rounded,
                        tooltip: 'Toggle Google Roadmap / Satellite',
                        onTap: () => setState(() => _isHybridSatellite = !_isHybridSatellite),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4)),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lock_rounded, color: AppTheme.accentEmerald, size: 15),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${_lockedCategory.name.toUpperCase()} TIER • ${isDelivery ? "PA-DELIVER" : "BOOK A RIDE"}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primarySlate,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_isRouting)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildFloatingCircleButton(
                        icon: Icons.admin_panel_settings_rounded,
                        tooltip: 'TODA/MINC Admin Portal',
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const WebAdminPortalScreen()),
                          );
                          _recalculateFareFromCurrentDistance();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Interactive Map-Tap Mode Switcher Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.primarySlate.withOpacity(0.88),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.touch_app_rounded, color: Colors.amber, size: 15),
                        const SizedBox(width: 6),
                        const Text(
                          'Tap map to set: ',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _tapMapSetsDropoff = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: !_tapMapSetsDropoff ? AppTheme.accentEmerald : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Pickup',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => setState(() => _tapMapSetsDropoff = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _tapMapSetsDropoff ? Colors.redAccent : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Where to? (Dropoff)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
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
          ),

          // 3. Bottom Destination & Book Ride Sheet (Duplicate Service Chips Removed)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4)),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Free Searchable Pickup & "Where to?" Destination Box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () => _openFreeLocationSearchSheet(isSelectingPickup: true),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.radio_button_checked, color: AppTheme.accentEmerald, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isDelivery ? 'PICKUP / SENDER LOCATION (AUTO-GPS)' : 'PICKUP LOCATION (AUTO-GPS)',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _pickupPoint.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.primarySlate,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Pinpoint My Current GPS Location',
                                    icon: const Icon(Icons.my_location_rounded, size: 18, color: AppTheme.accentEmerald),
                                    onPressed: () => _useCurrentGpsForPickup(silent: false),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Divider(height: 1, color: Colors.grey.shade200),
                          ),
                          InkWell(
                            onTap: () => _openFreeLocationSearchSheet(isSelectingPickup: false),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 19),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isDelivery
                                              ? 'DELIVERY DROPOFF RECIPIENT (Tap to search or tap map)'
                                              : 'WHERE TO? (Tap to search any place or tap map)',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _dropoffPoint.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.primarySlate,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.search_rounded, size: 19, color: AppTheme.primarySlate),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (isDelivery) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _deliveryNotesController,
                        decoration: const InputDecoration(
                          hintText: 'Item description / Recipient name & contact (e.g. 1 box documents)...',
                          prefixIcon: Icon(Icons.inventory_2_outlined, size: 18),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Next Step CTA -> Opens Bill Summary & Payment Method Screen ("Book Ride")
                    ElevatedButton(
                      onPressed: _proceedToBillSummary,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDelivery ? const Color(0xFFD97706) : AppTheme.accentEmerald,
                        foregroundColor: Colors.white,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(isDelivery ? 'Book Pa-Deliver' : 'Book Ride'),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '₱${_fareBreakdown.finalFare.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
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
  final bool isSelectingPickup;
  final String initialQuery;

  const _LocationSearchSheet({
    required this.isSelectingPickup,
    required this.initialQuery,
  });

  @override
  State<_LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<_LocationSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  List<LocationPoint> _results = LocationService.laoagLandmarks;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.isSelectingPickup ? 'Set Pickup Location' : 'Where to? (Any Destination)',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primarySlate,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: _onQueryChanged,
            decoration: InputDecoration(
              hintText: 'Type any street, barangay, store, hotel, or school in Laoag...',
              prefixIcon: Icon(
                widget.isSelectingPickup ? Icons.my_location_rounded : Icons.search_rounded,
                color: widget.isSelectingPickup ? AppTheme.accentEmerald : Colors.redAccent,
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
                  : (_searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _onQueryChanged('');
                          },
                        )
                      : null),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _searchController.text.trim().isEmpty
                ? 'POPULAR LAOAG DESTINATIONS (OR TYPE ANY PLACE ABOVE)'
                : 'LIVE SEARCH RESULTS IN LAOAG CITY / ILOCOS NORTE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: _results.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, index) {
                final place = _results[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.place_rounded,
                      color: widget.isSelectingPickup ? AppTheme.accentEmerald : Colors.redAccent,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    place.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.primarySlate,
                    ),
                  ),
                  subtitle: Text(
                    'GPS: ${place.latitude.toStringAsFixed(4)}, ${place.longitude.toStringAsFixed(4)}',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                  ),
                  onTap: () => Navigator.pop(context, place),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
