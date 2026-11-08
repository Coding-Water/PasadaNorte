import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _LiveRideTrackingScreenState extends State<LiveRideTrackingScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  Timer? _dispatchTimer;
  Timer? _trackingTimer;
  late AnimationController _radarPulseController;

  // Phase 0 (Screen 26): "Finding you a nearby driver..." (Live map with concentric green radar rings)
  // Phase 1 (Screens 27 & 28): "Driver is heading to your location..." (Collapsed / Expanded bottom sheet)
  bool _isWaitingForAcceptance = true;
  bool _isSheetExpanded = false;
  int _waitSecondsElapsed = 0;

  // Street-snapped Tricycle Live Approach Coordinates (from nearest TODA terminal to passenger pickup)
  List<LatLng> _tricycleApproachPath = [];
  int _currentApproachIndex = 0;
  late LatLng _tricycleLivePos;
  double _tricycleBearingRadians = 0.0;
  int _etaToPassengerMinutes = 2;
  double _distanceToPassengerMeters = 450;
  bool _hasArrivedAtPickup = false;

  // Verified Driver & Vehicle Documentation Data (Matched from Rank #1 TODA Pila)
  final Map<String, String> _matchedDriver = {
    'name': 'Manong Danilo "Danny" Pascua',
    'rating': '4.9',
    'rideOrders': '1,420',
    'yearsExp': '6',
    'memberSince': 'Jan 15, 2021',
    'toda': 'Laoag Central & San Jose TODA • Rank #1 Pila',
    'bodyNumber': 'MTOP #0418',
    'plateNumber': 'IN-4829',
    'phone': '+63 917 840 2291',
    'vehicleModel': 'Honda TMX 125 Alpha Tricycle',
    'color': 'Emerald Green & White Sidecar',
    'vehicleHeadline': 'Honda TMX 125 Tricycle, Green • Body #0418',
    'verifiedBadge': '1:1 Biometric & 4-Angle Vehicle Verified',
  };

  @override
  void initState() {
    super.initState();
    _radarPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _tricycleLivePos = LocationPoint(
      name: 'Nearest Queued TODA Terminal',
      latitude: widget.pickupPoint.latitude - 0.0024,
      longitude: widget.pickupPoint.longitude - 0.0018,
      zoneCode: 'TODA',
    ).latLng;

    _buildApproachTrajectory();
    _startWaitingForAcceptance();
  }

  double _computeBearingRadians(LatLng from, LatLng to) {
    final dLat = to.latitude - from.latitude;
    final dLng = to.longitude - from.longitude;
    if (dLat.abs() < 1e-7 && dLng.abs() < 1e-7) return _tricycleBearingRadians;
    // Angle relative to North (upward on map)
    return atan2(dLng, dLat);
  }

  Future<void> _buildApproachTrajectory() async {
    final todaStartPoint = LocationPoint(
      name: 'Laoag TODA Terminal Dispatch Point',
      latitude: widget.pickupPoint.latitude - 0.0024,
      longitude: widget.pickupPoint.longitude - 0.0018,
      zoneCode: 'TODA',
    );

    final approachRoute = await LocationService.fetchRoadRoute(
      todaStartPoint,
      widget.pickupPoint,
    );

    if (!mounted) return;
    setState(() {
      _tricycleApproachPath = approachRoute.polylinePoints.isNotEmpty
          ? approachRoute.polylinePoints
          : [todaStartPoint.latLng, widget.pickupPoint.latLng];
      _currentApproachIndex = 0;
      _tricycleLivePos = _tricycleApproachPath.first;
      if (_tricycleApproachPath.length > 1) {
        _tricycleBearingRadians = _computeBearingRadians(
          _tricycleApproachPath[0],
          _tricycleApproachPath[1],
        );
      }
      _distanceToPassengerMeters =
          (approachRoute.distanceKm * 1000).clamp(120, 1500);
      _etaToPassengerMinutes = approachRoute.durationMinutes.clamp(1, 5);
    });
  }

  void _startWaitingForAcceptance() {
    _dispatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _waitSecondsElapsed++;
      });
      // After 4 seconds of radar pulse, Rank #1 queued tricycle accepts the booking
      if (_waitSecondsElapsed >= 4) {
        timer.cancel();
        setState(() {
          _isWaitingForAcceptance = false;
        });
        _startLiveTricycleMovement();
      }
    });
  }

  void _startLiveTricycleMovement() {
    final double initialDistMeters =
        _distanceToPassengerMeters > 0 ? _distanceToPassengerMeters : 450;
    final int initialEtaMins =
        _etaToPassengerMinutes > 0 ? _etaToPassengerMinutes : 2;

    _trackingTimer = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      if (!mounted) return;
      if (_tricycleApproachPath.length > 1 &&
          _currentApproachIndex < _tricycleApproachPath.length - 1) {
        setState(() {
          final prevPos = _tricycleApproachPath[_currentApproachIndex];
          _currentApproachIndex++;
          final nextPos = _tricycleApproachPath[_currentApproachIndex];
          _tricycleBearingRadians = _computeBearingRadians(prevPos, nextPos);
          _tricycleLivePos = nextPos;

          final remainingRatio = 1.0 -
              (_currentApproachIndex / (_tricycleApproachPath.length - 1));
          _distanceToPassengerMeters =
              (initialDistMeters * remainingRatio).clamp(0, initialDistMeters);
          _etaToPassengerMinutes =
              (initialEtaMins * remainingRatio).ceil().clamp(1, initialEtaMins);
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
    _radarPulseController.dispose();
    super.dispose();
  }

  void _recenterMap() {
    _mapController.move(widget.pickupPoint.latLng, 16.2);
  }

  // Joyride Screen 29: Driver Information + PasadaNorte 4-Angle Tricycle Documentation
  void _openDriverInformationScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _DriverInformationScreen(
          driverData: _matchedDriver,
          onOpenChat: _openDriverChatScreen,
          onOpenCall: _openDriverVoiceCallScreen,
        ),
      ),
    );
  }

  // Joyride Screen 30: In-App Chat with Driver
  void _openDriverChatScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _DriverChatScreen(
          driverData: _matchedDriver,
          passengerName: widget.passengerName,
          pickupName: widget.pickupPoint.name,
          onOpenCall: _openDriverVoiceCallScreen,
        ),
      ),
    );
  }

  // Joyride Screen 31: Voice Call Screen
  void _openDriverVoiceCallScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _DriverVoiceCallScreen(
          driverData: _matchedDriver,
        ),
      ),
    );
  }

  // Joyride Screen 43 & 44: Cancel Ride Reason Selection & Confirmation
  void _openCancelRideScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const _CancelRideReasonScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDelivery = widget.fareBreakdown.tripType == TripType.pabiliPadala;
    final remainingApproachPoints = _tricycleApproachPath.isNotEmpty
        ? _tricycleApproachPath.sublist(_currentApproachIndex)
        : <LatLng>[];

    // Calculate dynamic bottom padding for the map and floating buttons
    final double bottomSheetHeight = _isWaitingForAcceptance
        ? 250.0
        : (_isSheetExpanded ? 495.0 : 265.0);

    return Scaffold(
      body: Stack(
        children: [
          // 1. FULL-BLEED INTERACTIVE MAP (Used in BOTH Screen 26 Waiting & Screen 27/28 Accepted!)
          Positioned.fill(
            bottom: bottomSheetHeight - 28,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.pickupPoint.latLng,
                initialZoom: 16.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                  userAgentPackageName: 'ph.laoag.pasadanorte',
                ),

                // When Driver Accepted (Screens 27 & 28): Show Street-Snapped Green Route Line
                if (!_isWaitingForAcceptance)
                  PolylineLayer(
                    polylines: [
                      // Planned passenger destination route (subtle slate line)
                      if (widget.routePolyline.length > 1)
                        Polyline(
                          points: widget.routePolyline,
                          strokeWidth: 3.5,
                          color: const Color(0xFF94A3B8).withValues(alpha: 0.45),
                        ),
                      // Active street-snapped driver approach line (Joyride vibrant green #00B14F)
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
                    // SCREEN 26: Animated Concentric Green Radar Rings Around Passenger Avatar
                    if (_isWaitingForAcceptance)
                      Marker(
                        point: widget.pickupPoint.latLng,
                        width: 260,
                        height: 260,
                        child: AnimatedBuilder(
                          animation: _radarPulseController,
                          builder: (context, child) {
                            final scale =
                                0.88 + (_radarPulseController.value * 0.14);
                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 250,
                                height: 250,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.accentEmerald
                                      .withValues(alpha: 0.14),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 175,
                                    height: 175,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppTheme.accentEmerald
                                          .withValues(alpha: 0.22),
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 108,
                                        height: 108,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppTheme.accentEmerald
                                              .withValues(alpha: 0.42),
                                        ),
                                        child: Center(
                                          child: _buildPassengerPinAvatar(
                                              size: 62),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    // SCREENS 27 & 28: Green Teardrop Pin with Passenger Avatar at Pickup Point
                    if (!_isWaitingForAcceptance)
                      Marker(
                        point: widget.pickupPoint.latLng,
                        width: 74,
                        height: 82,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 62,
                              height: 62,
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: AppTheme.accentEmerald,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: _buildPassengerPinAvatar(size: 50),
                            ),
                            const CustomPaint(
                              size: Size(16, 10),
                              painter: _PinTrianglePainter(
                                color: AppTheme.accentEmerald,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // SCREENS 27 & 28: Live Moving Top-Down Vehicle / Tricycle Marker Along Street Line
                    if (!_isWaitingForAcceptance)
                      Marker(
                        point: _tricycleLivePos,
                        width: 64,
                        height: 64,
                        child: Transform.rotate(
                          angle: _tricycleBearingRadians,
                          child: Center(
                            child: Container(
                              width: 38,
                              height: 54,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF1E293B),
                                  width: 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Icon(
                                    Icons.electric_rickshaw_rounded,
                                    size: 18,
                                    color: AppTheme.accentEmerald,
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    width: 22,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentEmerald,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // 2. FLOATING TOP PICKUP & DESTINATION CARD (Exact Joyride Screens 26, 27, 28)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: AppTheme.accentEmerald,
                          size: 21,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.pickupPoint.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primarySlate,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 28, top: 8, bottom: 8),
                      child: Divider(
                        height: 1,
                        color: Colors.grey.shade200,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: AppTheme.cancelRed,
                          size: 21,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.dropoffPoint.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primarySlate,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. FLOATING CIRCULAR BACK (<) AND GPS TARGET BUTTONS ABOVE BOTTOM SHEET (Joyride Screens 26 & 27)
          if (!_isSheetExpanded) ...[
            Positioned(
              left: 18,
              bottom: bottomSheetHeight + 14,
              child: _buildFloatingMapCircleButton(
                icon: Icons.chevron_left_rounded,
                size: 26,
                onTap: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              right: 18,
              bottom: bottomSheetHeight + 14,
              child: _buildFloatingMapCircleButton(
                icon: Icons.my_location_rounded,
                size: 22,
                onTap: _recenterMap,
              ),
            ),
          ],

          // 4. BOTTOM SHEET (Switches cleanly between Screen 26 Finding Driver & Screens 27/28 Driver Heading)
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 24,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: _isWaitingForAcceptance
                    ? _buildFindingNearbyDriverSheet()
                    : _buildDriverHeadingSheet(isDelivery: isDelivery),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // SCREEN 26: "Finding you a nearby driver..." Bottom Sheet
  Widget _buildFindingNearbyDriverSheet() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Finding you a nearby driver...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.primarySlate,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The driver will pick you up as soon as possible after they confirm your order.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          // Concentric Green Bullseye Target Indicator
          AnimatedBuilder(
            animation: _radarPulseController,
            builder: (context, _) {
              return Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.accentEmerald.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.accentEmerald.withValues(alpha: 0.75),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 15,
                        height: 15,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.accentEmerald,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          // Red Outlined Pill Button: "Cancel Ride"
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: _openCancelRideScreen,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.cancelRed,
                side: const BorderSide(color: AppTheme.cancelRed, width: 1.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Cancel Ride',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.cancelRed,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // SCREENS 27 (Collapsed) & 28 (Expanded): "Driver is heading to your location..."
  Widget _buildDriverHeadingSheet({required bool isDelivery}) {
    final fb = widget.fareBreakdown;
    final double grossFare = fb.baseFare + fb.distanceFare;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -150) {
          setState(() => _isSheetExpanded = true);
        } else if ((details.primaryVelocity ?? 0) > 150) {
          setState(() => _isSheetExpanded = false);
        }
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tap or drag handle to expand/collapse between Screen 27 and Screen 28
            InkWell(
              onTap: () => setState(() => _isSheetExpanded = !_isSheetExpanded),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isSheetExpanded
                          ? 'Tap or swipe down to collapse'
                          : 'Tap or swipe up for trip & vehicle details',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Headline: "Driver is heading to your location..."
            Text(
              _hasArrivedAtPickup
                  ? 'Driver has arrived at your location!'
                  : 'Driver is heading to your location...',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.primarySlate,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _hasArrivedAtPickup
                  ? 'Waiting at ${widget.pickupPoint.name}'
                  : 'Driver will arrive in $_etaToPassengerMinutes min... (${_distanceToPassengerMeters.toStringAsFixed(0)}m away)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _matchedDriver['vehicleHeadline']!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.primarySlate,
              ),
            ),

            const SizedBox(height: 16),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 14),

            // Driver Profile Row + Green Outlined Chat & Call Buttons (Joyride Screens 27 & 28)
            Row(
              children: [
                GestureDetector(
                  onTap: _openDriverInformationScreen,
                  child: _buildDriverAvatar(size: 56),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: GestureDetector(
                    onTap: _openDriverInformationScreen,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _matchedDriver['name']!,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primarySlate,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _matchedDriver['rating']!,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              Icons.phone_outlined,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                _matchedDriver['phone']!,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Chat Button (Screen 30)
                _buildGreenOutlinedIconButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  tooltip: 'Chat with Driver',
                  onTap: _openDriverChatScreen,
                ),
                const SizedBox(width: 10),
                // Call Button (Screen 31)
                _buildGreenOutlinedIconButton(
                  icon: Icons.phone_outlined,
                  tooltip: 'Call Driver',
                  onTap: _openDriverVoiceCallScreen,
                ),
              ],
            ),

            // EXPANDED CONTENT (Screen 28): Registered Front Tricycle Photo + Ride/Payment + Fare Summary + Cancel Ride
            if (_isSheetExpanded) ...[
              const SizedBox(height: 16),
              Divider(height: 1, color: Colors.grey.shade200),
              const SizedBox(height: 14),

              // PasadaNorte Case Study Requirement: Registered Tricycle Front Photo & 4-Angle Documentation
              InkWell(
                onTap: _openDriverInformationScreen,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentEmeraldLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.accentEmerald.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 72,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppTheme.accentEmerald,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.electric_rickshaw_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                            Text(
                              'FRONT VIEW',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 7.5,
                                fontWeight: FontWeight.w900,
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
                            const Text(
                              'Verified Tricycle (Front Photo & 4 Angles)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primarySlate,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_matchedDriver['toda']} • Tap for Driver Info & 4 Photos',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.accentEmerald,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Ride & Payment Summary Box (Exact Joyride Screen 28 layout)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                ),
                child: Column(
                  children: [
                    _buildSummaryLine(
                      'Ride',
                      isDelivery
                          ? 'PasadaNorte Pa-Deliver'
                          : 'PasadaNorte Tricycle (${fb.category.name.toUpperCase()})',
                    ),
                    const SizedBox(height: 10),
                    _buildSummaryLine(
                      'Payment',
                      widget.paymentMethod.split(' (').first,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Trip Fare / Discounts / Total Paid Box (Exact Joyride Screen 28 layout)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                ),
                child: Column(
                  children: [
                    _buildSummaryLine(
                      'Trip Fare (${fb.distanceKm.toStringAsFixed(2)} km)',
                      '₱${grossFare.toStringAsFixed(2)}',
                    ),
                    if (fb.discountAmount > 0) ...[
                      const SizedBox(height: 10),
                      _buildSummaryLine(
                        'Discounts (${fb.category.name.toUpperCase()} Ordinance)',
                        '- ₱${fb.discountAmount.toStringAsFixed(2)}',
                        valueColor: AppTheme.accentEmerald,
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: Colors.grey.shade200),
                    ),
                    _buildSummaryLine(
                      'Total Paid',
                      '₱${fb.finalFare.toStringAsFixed(2)}',
                      isBold: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Cancel Ride Outlined Red Pill Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _openCancelRideScreen,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.cancelRed,
                    side:
                        const BorderSide(color: AppTheme.cancelRed, width: 1.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Cancel Ride',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.cancelRed,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryLine(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 15 : 14,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
            color: valueColor ?? AppTheme.primarySlate,
          ),
        ),
      ],
    );
  }

  Widget _buildPassengerPinAvatar({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE2E8F0),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8),
        ],
      ),
      child: ClipOval(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: size * 0.58,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDriverAvatar({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF818CF8), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          color: Colors.white,
          size: size * 0.62,
        ),
      ),
    );
  }

  Widget _buildGreenOutlinedIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.accentEmerald, width: 1.6),
          ),
          child: Icon(
            icon,
            color: AppTheme.accentEmerald,
            size: 21,
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingMapCircleButton({
    required IconData icon,
    required double size,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Icon(
              icon,
              size: size,
              color: AppTheme.primarySlate,
            ),
          ),
        ),
      ),
    );
  }
}

class _PinTrianglePainter extends CustomPainter {
  final Color color;

  const _PinTrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PinTrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}

// ============================================================================
// JOYRIDE SCREEN 29: DRIVER INFORMATION + PASADANORTE 4-ANGLE VEHICLE PHOTOS
// ============================================================================
class _DriverInformationScreen extends StatelessWidget {
  final Map<String, String> driverData;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenCall;

  const _DriverInformationScreen({
    required this.driverData,
    required this.onOpenChat,
    required this.onOpenCall,
  });

  @override
  Widget build(BuildContext context) {
    final angles = [
      {'badge': 'FRONT VIEW', 'desc': 'MTOP #0418 • Headlamp & Windshield'},
      {'badge': 'BACK VIEW', 'desc': 'Plate #IN-4829 • Rear Reflectors'},
      {'badge': 'LEFT VIEW', 'desc': 'Honda TMX 125 • TODA Sticker'},
      {'badge': 'RIGHT VIEW', 'desc': 'Sidecar Entrance & Fare Matrix'},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Driver Information'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // 1. Top Driver Avatar, Name & Copyable Phone Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 24, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFF818CF8), Color(0xFF6366F1)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 56,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            driverData['name']!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primarySlate,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(text: driverData['phone']!),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Driver phone number copied'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  driverData['phone']!,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.copy_rounded,
                                  size: 16,
                                  color: Colors.grey.shade500,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 2. Rating / Ride Orders / Years Card (Exact Joyride Screen 29)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatColumn(
                            icon: Icons.star_outline_rounded,
                            value: driverData['rating']!,
                            label: 'Rating',
                          ),
                          _buildStatColumn(
                            icon: Icons.electric_rickshaw_outlined,
                            value: driverData['rideOrders']!,
                            label: 'Ride orders',
                          ),
                          _buildStatColumn(
                            icon: Icons.access_time_rounded,
                            value: driverData['yearsExp']!,
                            label: 'Years',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 3. Member Since / Vehicle Model / Color / Plate Number Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                              'Member Since', driverData['memberSince']!),
                          const SizedBox(height: 14),
                          _buildDetailRow(
                              'Tricycle Model', driverData['vehicleModel']!),
                          const SizedBox(height: 14),
                          _buildDetailRow('Color', driverData['color']!),
                          const SizedBox(height: 14),
                          _buildDetailRow(
                              'MTOP Body Number', driverData['bodyNumber']!),
                          const SizedBox(height: 14),
                          _buildDetailRow(
                              'Plate Number', driverData['plateNumber']!),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 4. PasadaNorte 4-Angle Registered Tricycle Photos Grid
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '4-Angle Verified Tricycle Documentation',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primarySlate,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: angles.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 1.55,
                            ),
                            itemBuilder: (context, index) {
                              final item = angles[index];
                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentEmeraldLight,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppTheme.accentEmerald
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.electric_rickshaw_rounded,
                                      color: AppTheme.accentEmerald,
                                      size: 26,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item['badge']!,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w900,
                                        color: AppTheme.accentEmerald,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item['desc']!,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Action Bar: Call (Soft Mint Pill) & Chat (Solid Green Pill)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 12,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onOpenCall();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentEmeraldLight,
                          foregroundColor: AppTheme.accentEmerald,
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.phone_rounded, size: 19),
                        label: const Text('Call'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onOpenChat();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentEmerald,
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                        label: const Text('Chat'),
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

  Widget _buildStatColumn({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade200, width: 1.5),
          ),
          child: Icon(icon, color: AppTheme.primarySlate, size: 24),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppTheme.primarySlate,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.primarySlate,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// JOYRIDE SCREEN 30: CHAT WITH DRIVER
// ============================================================================
class _DriverChatScreen extends StatefulWidget {
  final Map<String, String> driverData;
  final String passengerName;
  final String pickupName;
  final VoidCallback onOpenCall;

  const _DriverChatScreen({
    required this.driverData,
    required this.passengerName,
    required this.pickupName,
    required this.onOpenCall,
  });

  @override
  State<_DriverChatScreen> createState() => _DriverChatScreenState();
}

class _DriverChatScreenState extends State<_DriverChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  late final List<Map<String, dynamic>> _messages;

  @override
  void initState() {
    super.initState();
    _messages = [
      {
        'isMe': false,
        'text': 'Naimbag nga aldaw, ${widget.passengerName}!',
        'time': '09:41',
      },
      {
        'isMe': false,
        'text':
            "I'm ${widget.driverData['name']}. I'm on my way to your location (${widget.pickupName}). Please wait... ⏳😄",
        'time': '09:41',
      },
      {
        'isMe': true,
        'text':
            'Hello Manong, ok I will be waiting for you at ${widget.pickupName}. You can contact me as soon as you arrive 😄',
        'time': '09:41',
      },
      {
        'isMe': false,
        'text': "Great! I'll be there in less than 2 minutes 🔥",
        'time': '09:42',
      },
    ];
  }

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add({
        'isMe': true,
        'text': text,
        'time': 'Now',
      });
      _msgController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.driverData['name']!),
        actions: [
          IconButton(
            onPressed: widget.onOpenCall,
            icon: const Icon(Icons.phone_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _messages.length,
                itemBuilder: (context, idx) {
                  final m = _messages[idx];
                  final isMe = m['isMe'] as bool;
                  return Align(
                    alignment:
                        isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.76,
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isMe
                            ? AppTheme.accentEmerald
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            m['text'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: isMe
                                  ? Colors.white
                                  : AppTheme.primarySlate,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            m['time'] as String,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isMe
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Send a message...',
                        prefixIcon: Icon(
                          Icons.sentiment_satisfied_alt_rounded,
                          color: Colors.grey.shade500,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: _sendMessage,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accentEmerald,
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
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

// ============================================================================
// JOYRIDE SCREEN 31: VOICE CALL SCREEN
// ============================================================================
class _DriverVoiceCallScreen extends StatefulWidget {
  final Map<String, String> driverData;

  const _DriverVoiceCallScreen({required this.driverData});

  @override
  State<_DriverVoiceCallScreen> createState() => _DriverVoiceCallScreenState();
}

class _DriverVoiceCallScreenState extends State<_DriverVoiceCallScreen> {
  Timer? _callTimer;
  int _seconds = 0;
  bool _speakerOn = true;
  bool _micMuted = false;

  @override
  void initState() {
    super.initState();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(int totalSec) {
    final mins = (totalSec ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSec % 60).toString().padLeft(2, '0');
    return '$mins:$secs mins';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF38EF7D),
              Color(0xFF11998E),
              Color(0xFF1E3C72),
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                  ),
                ),
              ),
              Column(
                children: [
                  Container(
                    width: 146,
                    height: 146,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF818CF8),
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 86,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.driverData['name']!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _formatDuration(_seconds),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 42),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Hang Up Button (Red Circle)
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 62,
                        height: 62,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.cancelRed,
                        ),
                        child: const Icon(
                          Icons.call_end_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Speaker Button
                    InkWell(
                      onTap: () => setState(() => _speakerOn = !_speakerOn),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white
                              .withValues(alpha: _speakerOn ? 0.35 : 0.18),
                        ),
                        child: Icon(
                          _speakerOn
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Mic Mute Button
                    InkWell(
                      onTap: () => setState(() => _micMuted = !_micMuted),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white
                              .withValues(alpha: _micMuted ? 0.35 : 0.18),
                        ),
                        child: Icon(
                          _micMuted
                              ? Icons.mic_off_rounded
                              : Icons.mic_rounded,
                          color: Colors.white,
                          size: 26,
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
    );
  }
}

// ============================================================================
// JOYRIDE SCREENS 43 & 44: CANCEL RIDE REASON & CANCELED CONFIRMATION
// ============================================================================
class _CancelRideReasonScreen extends StatefulWidget {
  const _CancelRideReasonScreen();

  @override
  State<_CancelRideReasonScreen> createState() =>
      _CancelRideReasonScreenState();
}

class _CancelRideReasonScreenState extends State<_CancelRideReasonScreen> {
  int _selectedReasonIndex = 0;

  static const List<String> _reasons = [
    'Change in plans',
    'Waiting for long time',
    'Unable to contact driver',
    'Driver denied to go to destination',
    'Driver denied to come to pickup',
    'Wrong address shown',
    'The price is not reasonable',
    'Emergency situation',
    'Booking mistake',
    'Poor weather conditions',
    'Other',
  ];

  void _confirmCancel() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentEmerald,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Ride has been canceled!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primarySlate,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your dispatch request has been canceled without penalty. You can book a new ride anytime.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
        title: const Text('Cancel Ride'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 12, 22, 8),
              child: Text(
                'Why are you cancelling?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primarySlate,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _reasons.length,
                itemBuilder: (context, index) {
                  final selected = _selectedReasonIndex == index;
                  return ListTile(
                    onTap: () => setState(() => _selectedReasonIndex = index),
                    leading: Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: AppTheme.accentEmerald,
                      size: 22,
                    ),
                    title: Text(
                      _reasons[index],
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primarySlate,
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _confirmCancel,
                  child: const Text('Confirm'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
