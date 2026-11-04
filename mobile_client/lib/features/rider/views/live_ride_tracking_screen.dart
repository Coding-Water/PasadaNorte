import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../fare/services/fare_calculator_service.dart';

class LiveRideTrackingScreen extends StatefulWidget {
  final String passengerName;
  final LocationPoint pickupPoint;
  final LocationPoint dropoffPoint;
  final List<LatLng> routePolyline;
  final FareBreakdown fareBreakdown;
  final String paymentMethod;
  final String deliveryNotes;

  const LiveRideTrackingScreen({
    super.key,
    required this.passengerName,
    required this.pickupPoint,
    required this.dropoffPoint,
    required this.routePolyline,
    required this.fareBreakdown,
    required this.paymentMethod,
    this.deliveryNotes = '',
  });

  @override
  State<LiveRideTrackingScreen> createState() => _LiveRideTrackingScreenState();
}

class _LiveRideTrackingScreenState extends State<LiveRideTrackingScreen> {
  final MapController _mapController = MapController();
  Timer? _dispatchTimer;
  Timer? _trackingTimer;

  // Phase 0: "Waiting for a tricycle to accept..."
  // Phase 1: Accepted & Tricycle En Route to Passenger (Live GPS Moving)
  // Phase 2: Tricycle Arrived at Passenger Pickup Point
  bool _isWaitingForAcceptance = true;
  int _waitSecondsElapsed = 0;

  // Simulated Tricycle Live Approach Coordinates (from nearest TODA terminal to passenger pickup)
  List<LatLng> _tricycleApproachPath = [];
  int _currentApproachIndex = 0;
  late LatLng _tricycleLivePos;
  int _etaToPassengerMinutes = 3;
  double _distanceToPassengerMeters = 480;
  bool _hasArrivedAtPickup = false;

  // Verified Driver & Vehicle Documentation Data (Matched from Rank #1 TODA Pila)
  final Map<String, String> _matchedDriver = {
    'name': 'Manong Danilo "Danny" Pascua',
    'rating': '4.9 ★ (342 Verified Rides)',
    'toda': 'Laoag Central & San Jose TODA • Rank #1 Pila',
    'bodyNumber': 'MTOP Body #0418',
    'plateNumber': 'Plate #IN-4829',
    'phone': '+63 917 840 2291',
    'tricycleColor': 'Emerald Green & White Sidecar (Honda TMX 125 Alpha)',
    'verifiedBadge': '1:1 Biometric & 4-Angle Vehicle Verified',
  };

  @override
  void initState() {
    super.initState();
    _buildApproachTrajectory();
    _startWaitingForAcceptance();
  }

  void _buildApproachTrajectory() {
    // Generate a smooth 18-step approach path from ~450m away (nearest TODA Pila) to the passenger's pickup point
    final startLat = widget.pickupPoint.latitude - 0.0032;
    final startLng = widget.pickupPoint.longitude - 0.0028;
    final endLat = widget.pickupPoint.latitude;
    final endLng = widget.pickupPoint.longitude;

    const int steps = 18;
    _tricycleApproachPath = List.generate(steps + 1, (i) {
      final t = i / steps;
      // Add slight street-grid bend at midpoint
      final midLatOffset = (t < 0.5) ? (t * 0.0006) : ((1 - t) * 0.0006);
      return LatLng(
        startLat + (endLat - startLat) * t + midLatOffset,
        startLng + (endLng - startLng) * t,
      );
    });
    _tricycleLivePos = _tricycleApproachPath.first;
  }

  void _startWaitingForAcceptance() {
    _dispatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _waitSecondsElapsed++;
      });
      // After 3 seconds, Rank #1 queued tricycle accepts the booking
      if (_waitSecondsElapsed >= 3) {
        timer.cancel();
        setState(() {
          _isWaitingForAcceptance = false;
        });
        _startLiveTricycleMovement();
      }
    });
  }

  void _startLiveTricycleMovement() {
    _trackingTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) {
      if (!mounted) return;
      if (_currentApproachIndex < _tricycleApproachPath.length - 1) {
        setState(() {
          _currentApproachIndex++;
          _tricycleLivePos = _tricycleApproachPath[_currentApproachIndex];
          final remainingRatio = 1.0 - (_currentApproachIndex / (_tricycleApproachPath.length - 1));
          _distanceToPassengerMeters = (480 * remainingRatio).clamp(0, 480);
          _etaToPassengerMinutes = (3 * remainingRatio).ceil().clamp(1, 3);
        });
      } else {
        timer.cancel();
        setState(() {
          _hasArrivedAtPickup = true;
          _distanceToPassengerMeters = 0;
          _etaToPassengerMinutes = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _dispatchTimer?.cancel();
    _trackingTimer?.cancel();
    super.dispose();
  }

  void _showFourAngleVehiclePhotosModal() {
    final angles = [
      {
        'title': 'Front View (Primary Identification)',
        'subtitle': 'MTOP Body #0418 • Green/White Sidecar • Windshield & Headlamp Inspected',
        'icon': Icons.electric_rickshaw_rounded,
        'badge': 'FRONT VIEW',
      },
      {
        'title': 'Back View (Rear Plate & Reflectors)',
        'subtitle': 'LTO Plate #IN-4829 • Rear Safety Reflector & Tail Lamp Verified',
        'icon': Icons.directions_car_filled_rounded,
        'badge': 'BACK VIEW',
      },
      {
        'title': 'Left Side View (Driver Motorcycle Side)',
        'subtitle': 'Honda TMX 125 Alpha • Muffler Shield & TODA Sticker Verified',
        'icon': Icons.two_wheeler_rounded,
        'badge': 'LEFT VIEW',
      },
      {
        'title': 'Right Side View (Passenger Sidecar Entrance)',
        'subtitle': 'Stepboard, Grab Bar, Rain Tarpaulin & Fare Matrix Sticker Verified',
        'icon': Icons.airline_seat_recline_normal_rounded,
        'badge': 'RIGHT VIEW',
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.76,
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
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verified Tricycle Vehicle Documentation',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primarySlate,
                        ),
                      ),
                      Text(
                        '4-Angle Registration Photos (Front, Back, Left, Right) • MINC Inspected',
                        style: TextStyle(fontSize: 11.5, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: angles.length,
                itemBuilder: (context, idx) {
                  final item = angles[idx];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.accentEmerald.withOpacity(0.45)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 84,
                          height: 74,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F172A), Color(0xFF065F46)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(item['icon'] as IconData, color: Colors.white, size: 30),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentEmerald,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item['badge'] as String,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.verified_rounded, color: AppTheme.accentEmerald, size: 15),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      item['title'] as String,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
                                        color: AppTheme.primarySlate,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['subtitle'] as String,
                                style: const TextStyle(fontSize: 11.5, color: Colors.black54, height: 1.35),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isWaitingForAcceptance) {
      return _buildWaitingForTricycleLoadingScreen();
    }

    final isDelivery = widget.fareBreakdown.tripType == TripType.pabiliPadala;
    final remainingApproachPoints = _tricycleApproachPath.sublist(_currentApproachIndex);

    return Scaffold(
      body: Column(
        children: [
          // TOP HALF: Interactive Google Map with Live Tricycle Tracking toward Passenger
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: widget.pickupPoint.latLng,
                    initialZoom: 16.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                      userAgentPackageName: 'ph.laoag.pasadanorte',
                    ),
                    // Planned Passenger Trip Route (Dashed/Muted Slate)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: widget.routePolyline,
                          strokeWidth: 4.0,
                          color: Colors.blueGrey.withOpacity(0.55),
                        ),
                        // Live Active Approach Route of Tricycle -> Passenger Pickup (Emerald Green)
                        if (remainingApproachPoints.length > 1)
                          Polyline(
                            points: remainingApproachPoints,
                            strokeWidth: 5.5,
                            color: AppTheme.accentEmerald,
                          ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        // Passenger Pickup Pin
                        Marker(
                          point: widget.pickupPoint.latLng,
                          width: 52,
                          height: 52,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.primarySlate,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                            ),
                            child: const Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 26),
                          ),
                        ),
                        // Destination Pin
                        Marker(
                          point: widget.dropoffPoint.latLng,
                          width: 44,
                          height: 44,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                            ),
                            child: const Icon(Icons.flag_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                        // LIVE MOVING TRICYCLE MARKER
                        Marker(
                          point: _tricycleLivePos,
                          width: 64,
                          height: 64,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primarySlate,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _hasArrivedAtPickup ? 'ARRIVED' : '${_distanceToPassengerMeters.toStringAsFixed(0)}m',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppTheme.accentEmerald,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accentEmerald.withOpacity(0.5),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.electric_rickshaw_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Top Live Tracking Status Pill
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 4,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.pop(context),
                            child: const Padding(
                              padding: EdgeInsets.all(10),
                              child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.primarySlate),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.primarySlate,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _hasArrivedAtPickup ? Colors.amber : const Color(0xFF4ADE80),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _hasArrivedAtPickup
                                        ? 'Tricycle has arrived at your pickup point!'
                                        : 'Tricycle on the way • $_etaToPassengerMinutes min (${_distanceToPassengerMeters.toStringAsFixed(0)}m away)',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // BOTTOM HALF: Driver Profile (with Picture) + Picture of Tricycle (Front View)
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4)),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Acceptance Status Banner
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_rounded, color: AppTheme.accentEmerald, size: 15),
                              const SizedBox(width: 5),
                              Text(
                                isDelivery ? 'PA-DELIVER ACCEPTED BY DRIVER' : 'TRICYCLE ACCEPTED • EN ROUTE',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.accentEmerald,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₱${widget.fareBreakdown.finalFare.toStringAsFixed(2)} • ${widget.paymentMethod.split(" ").first}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primarySlate,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Side-by-Side Driver Profile Photo & Tricycle Front Photo Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. DRIVER PROFILE PICTURE WITH VERIFIED BADGE
                              Stack(
                                children: [
                                  Container(
                                    width: 68,
                                    height: 68,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: AppTheme.accentEmerald, width: 2.5),
                                    ),
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.person_rounded, color: Colors.white, size: 36),
                                        Text(
                                          'DRIVER',
                                          style: TextStyle(
                                            color: Color(0xFF4ADE80),
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Positioned(
                                    right: -2,
                                    bottom: -2,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: AppTheme.accentEmerald,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.check, color: Colors.white, size: 12),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),

                              // Driver Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _matchedDriver['name']!,
                                      style: const TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w900,
                                        color: AppTheme.primarySlate,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _matchedDriver['toda']!,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primarySlate,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            _matchedDriver['bodyNumber']!,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade100,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            _matchedDriver['plateNumber']!,
                                            style: TextStyle(
                                              color: Colors.amber.shade900,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _matchedDriver['rating']!,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFD97706),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),

                          // 2. PICTURE OF THE TRICYCLE (FRONT VIEW) CARD
                          InkWell(
                            onTap: _showFourAngleVehiclePhotosModal,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.accentEmerald.withOpacity(0.5), width: 1.5),
                              ),
                              child: Row(
                                children: [
                                  // Visual Front-View Tricycle Photo Thumbnail
                                  Container(
                                    width: 96,
                                    height: 68,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF064E3B), Color(0xFF00B14F)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        const Icon(
                                          Icons.electric_rickshaw_rounded,
                                          color: Colors.white,
                                          size: 36,
                                        ),
                                        Positioned(
                                          bottom: 4,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.65),
                                              borderRadius: BorderRadius.circular(5),
                                            ),
                                            child: const Text(
                                              'TRICYCLE (FRONT)',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 8,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(Icons.camera_front_rounded, size: 14, color: AppTheme.accentEmerald),
                                            SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                'Registered Tricycle Photo (Front View)',
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppTheme.primarySlate,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _matchedDriver['tricycleColor']!,
                                          style: const TextStyle(fontSize: 11.5, color: Colors.black87),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Tap to view all 4 registered angles (Front, Back, Left, Right) →',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.accentEmerald,
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
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Action Buttons: View 4 Angles / Complete Ride
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showFourAngleVehiclePhotosModal,
                            icon: const Icon(Icons.photo_library_rounded, size: 17),
                            label: const Text('4 Vehicle Photos', style: TextStyle(fontSize: 12.5)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.popUntil(context, (route) => route.isFirst);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentEmerald,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.check_circle_rounded, size: 17),
                            label: const Text('Done / Home', style: TextStyle(fontSize: 12.5)),
                          ),
                        ),
                      ],
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

  Widget _buildWaitingForTricycleLoadingScreen() {
    return Scaffold(
      backgroundColor: AppTheme.primarySlate,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Pulse / Radar Container
              Container(
                width: 126,
                height: 126,
                decoration: BoxDecoration(
                  color: AppTheme.accentEmerald.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.accentEmerald.withOpacity(0.6), width: 2.5),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 68,
                    height: 68,
                    child: CircularProgressIndicator(
                      color: AppTheme.accentEmerald,
                      strokeWidth: 4.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Waiting for a tricycle to accept...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Dispatching your request to Rank #1 queued TODA tricycle near ${widget.pickupPoint.name}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.my_location_rounded, color: Color(0xFF4ADE80), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Pickup: ${widget.pickupPoint.name}',
                            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Destination: ${widget.dropoffPoint.name}',
                            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24, height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Locked Fare (${widget.fareBreakdown.category.name.toUpperCase()})',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          '₱${widget.fareBreakdown.finalFare.toStringAsFixed(2)} • ${widget.paymentMethod.split(" ").first}',
                          style: const TextStyle(
                            color: Color(0xFF4ADE80),
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                label: const Text(
                  'Cancel Dispatch Request',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
