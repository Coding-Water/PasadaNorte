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

enum _RidePhase {
  findingDriver, // Dispatching & finding a nearby TODA driver
  driverHeadingToPickup, // Driver is heading to passenger pickup location
  headingToDestination, // Passenger is on board heading to destination
  arrivedAtDestination, // Passenger has arrived at destination
}

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

  _RidePhase _ridePhase = _RidePhase.findingDriver;
  bool _isSheetExpanded = false;
  int _waitSecondsElapsed = 0;

  // Phase 1: Street-snapped Tricycle Approach Path (from nearest TODA terminal to passenger pickup)
  List<LatLng> _tricycleApproachPath = [];
  int _currentApproachIndex = 0;
  int _etaToPassengerMinutes = 2;
  double _distanceToPassengerMeters = 420;

  // Phase 2: Street-snapped Passenger Journey Path (from pickupPoint to dropoffPoint)
  List<LatLng> _destinationRoutePath = [];
  int _currentDestinationIndex = 0;
  double _totalTripDistanceKm = 1.2;
  int _totalTripDurationMinutes = 4;
  double _remainingDestinationKm = 1.2;
  int _etaToDestinationMinutes = 4;

  // Live Vehicle Position & Accurate Forward Street Bearing (0 rad = North / Up)
  late LatLng _tricycleLivePos;
  double _tricycleBearingRadians = 0.0;

  // Selected Mood during this trip (0..4, default 3 = Happy)
  int _selectedMoodIndex = 3;

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

    _totalTripDistanceKm = max(0.3, widget.fareBreakdown.distanceKm);
    _totalTripDurationMinutes =
        max(2, (_totalTripDistanceKm / 0.36).ceil().clamp(2, 25));
    _remainingDestinationKm = _totalTripDistanceKm;
    _etaToDestinationMinutes = _totalTripDurationMinutes;

    _destinationRoutePath = widget.routePolyline.length >= 2
        ? List<LatLng>.from(widget.routePolyline)
        : [widget.pickupPoint.latLng, widget.dropoffPoint.latLng];

    _tricycleLivePos = LocationPoint(
      name: 'Nearest Queued TODA Terminal',
      latitude: widget.pickupPoint.latitude - 0.0020,
      longitude: widget.pickupPoint.longitude - 0.0015,
      zoneCode: 'TODA',
    ).latLng;

    _prepareRoutesAndStartDispatch();
  }

  // Accurate spherical bearing in radians where 0 = North (up), pi/2 = East (right)
  double _computeBearingRadians(LatLng from, LatLng to) {
    final dLat = to.latitude - from.latitude;
    final dLng = to.longitude - from.longitude;
    if (dLat.abs() < 1e-7 && dLng.abs() < 1e-7) {
      return _tricycleBearingRadians;
    }
    final lat1 = from.latitude * pi / 180.0;
    final lat2 = to.latitude * pi / 180.0;
    final dLon = (to.longitude - from.longitude) * pi / 180.0;
    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    return atan2(y, x);
  }

  // Looks ahead along the polyline so the vehicle always points cleanly toward the next road segment
  double _computeForwardBearingOnPath(List<LatLng> path, int index) {
    if (path.length < 2) return _tricycleBearingRadians;
    final int clampedIdx = index.clamp(0, path.length - 1);
    final LatLng current = path[clampedIdx];

    for (int nextIdx = clampedIdx + 1; nextIdx < path.length; nextIdx++) {
      final candidate = path[nextIdx];
      final dLat = (candidate.latitude - current.latitude).abs();
      final dLng = (candidate.longitude - current.longitude).abs();
      if (dLat > 2e-5 || dLng > 2e-5) {
        return _computeBearingRadians(current, candidate);
      }
    }

    if (clampedIdx > 0) {
      return _computeBearingRadians(path[clampedIdx - 1], current);
    }
    return _tricycleBearingRadians;
  }

  Future<void> _prepareRoutesAndStartDispatch() async {
    final todaStartPoint = LocationPoint(
      name: 'Laoag TODA Terminal Dispatch Point',
      latitude: widget.pickupPoint.latitude - 0.0020,
      longitude: widget.pickupPoint.longitude - 0.0015,
      zoneCode: 'TODA',
    );

    final approachRoute = await LocationService.fetchRoadRoute(
      todaStartPoint,
      widget.pickupPoint,
    );

    if (_destinationRoutePath.length < 4) {
      final destRoute = await LocationService.fetchRoadRoute(
        widget.pickupPoint,
        widget.dropoffPoint,
      );
      if (destRoute.polylinePoints.length >= 2) {
        _destinationRoutePath = destRoute.polylinePoints;
        _totalTripDistanceKm = destRoute.distanceKm;
        _totalTripDurationMinutes = destRoute.durationMinutes;
      }
    }

    if (!mounted) return;
    setState(() {
      _tricycleApproachPath = approachRoute.polylinePoints.isNotEmpty
          ? approachRoute.polylinePoints
          : [todaStartPoint.latLng, widget.pickupPoint.latLng];
      _currentApproachIndex = 0;
      _tricycleLivePos = _tricycleApproachPath.first;
      _tricycleBearingRadians =
          _computeForwardBearingOnPath(_tricycleApproachPath, 0);
      _distanceToPassengerMeters =
          (approachRoute.distanceKm * 1000).clamp(120, 1200);
      _etaToPassengerMinutes = approachRoute.durationMinutes.clamp(1, 4);
    });

    _startWaitingForAcceptance();
  }

  void _startWaitingForAcceptance() {
    _dispatchTimer?.cancel();
    _dispatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _waitSecondsElapsed++;
      });
      // After 3 seconds of radar pulse, Rank #1 queued tricycle accepts the booking
      if (_waitSecondsElapsed >= 3) {
        timer.cancel();
        _beginDriverApproachPhase();
      }
    });
  }

  void _beginDriverApproachPhase() {
    if (!mounted) return;
    setState(() {
      _ridePhase = _RidePhase.driverHeadingToPickup;
    });

    final double initialDistMeters =
        _distanceToPassengerMeters > 0 ? _distanceToPassengerMeters : 400;
    final int initialEtaMins =
        _etaToPassengerMinutes > 0 ? _etaToPassengerMinutes : 2;
    // Step size so approach finishes smoothly in ~10 ticks (~5.5 seconds)
    final int stepIncrement =
        max(1, (_tricycleApproachPath.length / 10).ceil());

    _trackingTimer?.cancel();
    _trackingTimer =
        Timer.periodic(const Duration(milliseconds: 550), (timer) {
      if (!mounted) return;
      if (_tricycleApproachPath.length > 1 &&
          _currentApproachIndex < _tricycleApproachPath.length - 1) {
        setState(() {
          _currentApproachIndex = min(
            _tricycleApproachPath.length - 1,
            _currentApproachIndex + stepIncrement,
          );
          _tricycleLivePos = _tricycleApproachPath[_currentApproachIndex];
          _tricycleBearingRadians = _computeForwardBearingOnPath(
            _tricycleApproachPath,
            _currentApproachIndex,
          );

          final remainingRatio = 1.0 -
              (_currentApproachIndex / (_tricycleApproachPath.length - 1));
          _distanceToPassengerMeters =
              (initialDistMeters * remainingRatio).clamp(0, initialDistMeters);
          _etaToPassengerMinutes =
              (initialEtaMins * remainingRatio).ceil().clamp(1, initialEtaMins);
        });
        _followDriverApproach();
      } else {
        timer.cancel();
        // Driver has picked up the passenger — immediately transition to Phase 2 (Heading to Destination!)
        _beginHeadingToDestinationPhase();
      }
    });
  }

  @override
  void reassemble() {
    super.reassemble();
    // Ensure hot-reload immediately transitions if driver already reached pickup
    if (_ridePhase == _RidePhase.driverHeadingToPickup &&
        (_trackingTimer == null || !_trackingTimer!.isActive)) {
      _beginHeadingToDestinationPhase();
    }
  }

  // PHASE 2: Rider takes passenger and heads along road route from Point A (Pickup) to Point B (Destination)
  void _beginHeadingToDestinationPhase() {
    _trackingTimer?.cancel();
    if (!mounted) return;

    setState(() {
      _ridePhase = _RidePhase.headingToDestination;
      _isSheetExpanded = false;
      _currentDestinationIndex = 0;
      _tricycleLivePos = _destinationRoutePath.first;
      // Immediately orient the tricycle along the street toward the passenger's destination!
      _tricycleBearingRadians =
          _computeForwardBearingOnPath(_destinationRoutePath, 0);
      _remainingDestinationKm = _totalTripDistanceKm;
      _etaToDestinationMinutes = _totalTripDurationMinutes;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fitDestinationRouteBounds();
      }
    });

    // Advance along the road polyline so the passenger sees live distance/ETA countdown to their destination
    final int stepIncrement =
        max(1, (_destinationRoutePath.length / 20).ceil());

    _trackingTimer =
        Timer.periodic(const Duration(milliseconds: 650), (timer) {
      if (!mounted) return;
      if (_destinationRoutePath.length > 1 &&
          _currentDestinationIndex < _destinationRoutePath.length - 1) {
        setState(() {
          _currentDestinationIndex = min(
            _destinationRoutePath.length - 1,
            _currentDestinationIndex + stepIncrement,
          );
          _tricycleLivePos = _destinationRoutePath[_currentDestinationIndex];
          _tricycleBearingRadians = _computeForwardBearingOnPath(
            _destinationRoutePath,
            _currentDestinationIndex,
          );

          final remainingRatio = 1.0 -
              (_currentDestinationIndex / (_destinationRoutePath.length - 1));
          _remainingDestinationKm =
              (_totalTripDistanceKm * remainingRatio).clamp(
            0.0,
            _totalTripDistanceKm,
          );
          _etaToDestinationMinutes =
              (_totalTripDurationMinutes * remainingRatio)
                  .ceil()
                  .clamp(1, _totalTripDurationMinutes);
        });
        _followActiveDestinationJourney();
      } else {
        timer.cancel();
        _triggerArrivedAtDestinationPhase();
      }
    });
  }

  // PHASE 3: Passenger has arrived at their destination
  void _triggerArrivedAtDestinationPhase() {
    _trackingTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _ridePhase = _RidePhase.arrivedAtDestination;
      _isSheetExpanded = false;
      _currentDestinationIndex = _destinationRoutePath.length - 1;
      _tricycleLivePos = widget.dropoffPoint.latLng;
      _remainingDestinationKm = 0.0;
      _etaToDestinationMinutes = 0;
    });
    _mapController.move(widget.dropoffPoint.latLng, 16.5);
  }

  void _fitDestinationRouteBounds() {
    try {
      final pointsToFit = <LatLng>[
        widget.pickupPoint.latLng,
        _tricycleLivePos,
        widget.dropoffPoint.latLng,
        ..._destinationRoutePath,
      ];
      final bounds = LatLngBounds.fromPoints(pointsToFit);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.fromLTRB(54, 150, 54, 95),
          maxZoom: 16.2,
        ),
      );
    } catch (_) {
      _mapController.move(widget.dropoffPoint.latLng, 15.6);
    }
  }

  // Smoothly updates the map camera as the vehicle moves from Point A toward Point B
  // so both the moving tricycle and the destination (Point B) remain clearly framed on screen
  void _followActiveDestinationJourney() {
    try {
      final remainingSlice = _destinationRoutePath.sublist(
        _currentDestinationIndex.clamp(0, _destinationRoutePath.length - 1),
      );
      final points = <LatLng>[
        _tricycleLivePos,
        widget.dropoffPoint.latLng,
        ...remainingSlice,
      ];
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.fromLTRB(62, 155, 62, 100),
          maxZoom: 16.5,
        ),
      );
    } catch (_) {}
  }

  // Smoothly updates map camera so passenger watches the approaching tricycle close in
  // without needing to swipe or pan the screen
  void _followDriverApproach() {
    try {
      final points = <LatLng>[
        _tricycleLivePos,
        widget.pickupPoint.latLng,
      ];
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.fromLTRB(54, 150, 54, 110),
          maxZoom: 16.8,
        ),
      );
    } catch (_) {
      _mapController.move(_tricycleLivePos, 16.2);
    }
  }

  // Dynamic reroute listener when driver deviates due to traffic/road repairs
  void simulateDriverDetour() async {
    if (_ridePhase != _RidePhase.headingToDestination) return;
    final detourOrigin = LocationPoint(
      latitude: _tricycleLivePos.latitude + 0.00045,
      longitude: _tricycleLivePos.longitude - 0.00040,
      name: 'Driver Detour Point',
    );
    try {
      final detourResult = await LocationService.fetchRoadRoute(detourOrigin, widget.dropoffPoint);
      if (mounted && detourResult.polylinePoints.length >= 2) {
        setState(() {
          _destinationRoutePath = detourResult.polylinePoints;
          _currentDestinationIndex = 0;
          _tricycleLivePos = detourResult.polylinePoints.first;
          _remainingDestinationKm = detourResult.distanceKm;
        });
        _fitDestinationRouteBounds();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Driver Detour: Rerouted via alternate road due to local traffic/construction (+${detourResult.distanceKm} km).'),
            backgroundColor: Colors.amber.shade900,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _dispatchTimer?.cancel();
    _trackingTimer?.cancel();
    _radarPulseController.dispose();
    super.dispose();
  }

  void _recenterMap() {
    if (_ridePhase == _RidePhase.headingToDestination) {
      _fitDestinationRouteBounds();
    } else if (_ridePhase == _RidePhase.arrivedAtDestination) {
      _mapController.move(widget.dropoffPoint.latLng, 16.5);
    } else {
      _mapController.move(widget.pickupPoint.latLng, 16.2);
    }
  }

  String _formatRemainingDestinationDistance() {
    if (_remainingDestinationKm < 1.0) {
      final meters = max(20, (_remainingDestinationKm * 1000).round());
      return '$meters m';
    }
    return '${_remainingDestinationKm.toStringAsFixed(1)} km';
  }

  // Driver Information + PasadaNorte 4-Angle Tricycle Documentation
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

  // In-App Chat with Driver
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

  // Voice Call Screen
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

  // Cancel Ride Reason Selection & Confirmation
  void _openCancelRideScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const _CancelRideReasonScreen(),
      ),
    );
  }

  // Post-Trip Rating -> Add Tip -> Ride Completed
  void _openPostTripRateDriverFlow() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _RateDriverScreen(
          driverData: _matchedDriver,
          fareBreakdown: widget.fareBreakdown,
          paymentMethod: widget.paymentMethod,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDelivery = widget.fareBreakdown.tripType == TripType.pabiliPadala;

    // Polyline slices for Phase 1 (Approach) and Phase 2 (Heading to Destination)
    final remainingApproachPoints = _tricycleApproachPath.isNotEmpty
        ? _tricycleApproachPath.sublist(
            _currentApproachIndex.clamp(0, _tricycleApproachPath.length - 1),
          )
        : <LatLng>[];

    final traveledDestinationPoints = _destinationRoutePath.isNotEmpty
        ? _destinationRoutePath.sublist(
            0,
            (_currentDestinationIndex + 1)
                .clamp(1, _destinationRoutePath.length),
          )
        : <LatLng>[];

    final remainingDestinationPoints = _destinationRoutePath.isNotEmpty
        ? _destinationRoutePath.sublist(
            _currentDestinationIndex.clamp(
              0,
              _destinationRoutePath.length - 1,
            ),
          )
        : <LatLng>[];

    // Dynamic bottom sheet height per phase
    final double bottomSheetHeight = switch (_ridePhase) {
      _RidePhase.findingDriver => 250.0,
      _RidePhase.driverHeadingToPickup => _isSheetExpanded ? 495.0 : 285.0,
      _RidePhase.headingToDestination => _isSheetExpanded ? 480.0 : 295.0,
      _RidePhase.arrivedAtDestination => 520.0,
    };

    return Scaffold(
      body: Stack(
        children: [
          // 1. FULL-BLEED INTERACTIVE MAP
          Positioned.fill(
            bottom: _ridePhase == _RidePhase.arrivedAtDestination
                ? 0
                : (bottomSheetHeight - 28),
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

                // Phase 1 Polylines: Driver heading to pickup
                if (_ridePhase == _RidePhase.driverHeadingToPickup)
                  PolylineLayer(
                    polylines: [
                      if (_destinationRoutePath.length > 1)
                        Polyline(
                          points: _destinationRoutePath,
                          strokeWidth: 3.5,
                          color:
                              const Color(0xFF94A3B8).withValues(alpha: 0.45),
                        ),
                      if (remainingApproachPoints.length > 1)
                        Polyline(
                          points: remainingApproachPoints,
                          strokeWidth: 5.5,
                          color: AppTheme.accentEmerald,
                        ),
                    ],
                  ),

                // Phase 2 & 3 Polylines: Passenger in transit heading to destination
                if (_ridePhase == _RidePhase.headingToDestination ||
                    _ridePhase == _RidePhase.arrivedAtDestination)
                  PolylineLayer(
                    polylines: [
                      // Traveled segment from pickup to vehicle (soft mint trail)
                      if (traveledDestinationPoints.length > 1)
                        Polyline(
                          points: traveledDestinationPoints,
                          strokeWidth: 4.5,
                          color:
                              AppTheme.accentEmerald.withValues(alpha: 0.38),
                        ),
                      // Active remaining road route from vehicle to destination (vibrant green #00B14F)
                      if (remainingDestinationPoints.length > 1)
                        Polyline(
                          points: remainingDestinationPoints,
                          strokeWidth: 6.0,
                          color: AppTheme.accentEmerald,
                        ),
                    ],
                  ),

                MarkerLayer(
                  markers: [
                    // Animated Concentric Green Radar Rings Around Passenger Avatar
                    if (_ridePhase == _RidePhase.findingDriver)
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
                                            size: 62,
                                          ),
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

                    // Pickup Point Pin (Green Teardrop Pin)
                    if (_ridePhase != _RidePhase.findingDriver)
                      Marker(
                        point: widget.pickupPoint.latLng,
                        width: _ridePhase == _RidePhase.driverHeadingToPickup
                            ? 74
                            : 52,
                        height: _ridePhase == _RidePhase.driverHeadingToPickup
                            ? 82
                            : 60,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width:
                                  _ridePhase == _RidePhase.driverHeadingToPickup
                                      ? 62
                                      : 42,
                              height:
                                  _ridePhase == _RidePhase.driverHeadingToPickup
                                      ? 62
                                      : 42,
                              padding: const EdgeInsets.all(4),
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
                              child: _buildPassengerPinAvatar(
                                size: _ridePhase ==
                                        _RidePhase.driverHeadingToPickup
                                    ? 50
                                    : 32,
                              ),
                            ),
                            const CustomPaint(
                              size: Size(14, 8),
                              painter: _PinTrianglePainter(
                                color: AppTheme.accentEmerald,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Destination Pin (Red Teardrop Pin with Live Distance Pill)
                    if (_ridePhase == _RidePhase.headingToDestination ||
                        _ridePhase == _RidePhase.arrivedAtDestination)
                      Marker(
                        point: widget.dropoffPoint.latLng,
                        width: 120,
                        height: 108,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_ridePhase == _RidePhase.headingToDestination)
                              Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primarySlate,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _formatRemainingDestinationDistance(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            Container(
                              width: 58,
                              height: 58,
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: AppTheme.cancelRed,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.storefront_rounded,
                                  color: AppTheme.cancelRed,
                                  size: 24,
                                ),
                              ),
                            ),
                            const CustomPaint(
                              size: Size(16, 10),
                              painter: _PinTrianglePainter(
                                color: AppTheme.cancelRed,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Live Moving Top-Down Vehicle / Tricycle Marker Oriented Along the Street
                    if (_ridePhase != _RidePhase.findingDriver)
                      Marker(
                        point: _tricycleLivePos,
                        width: 130,
                        height: 98,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_ridePhase ==
                                    _RidePhase.driverHeadingToPickup ||
                                _ridePhase == _RidePhase.headingToDestination)
                              Container(
                                margin: const EdgeInsets.only(bottom: 3),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: _ridePhase ==
                                          _RidePhase.headingToDestination
                                      ? AppTheme.accentEmerald
                                      : AppTheme.primarySlate,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _ridePhase == _RidePhase.headingToDestination
                                      ? '${_formatRemainingDestinationDistance()} • ${_etaToDestinationMinutes}m'
                                      : '${_distanceToPassengerMeters.toStringAsFixed(0)}m',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            SizedBox(
                              width: 64,
                              height: 64,
                              child: Transform.rotate(
                                angle: _tricycleBearingRadians,
                                child: _buildTopDownTricycleMarker(),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // 2. FLOATING TOP PICKUP (POINT A) & DESTINATION (POINT B) CARD WITH LIVE DISTANCE
          if (_ridePhase != _RidePhase.arrivedAtDestination)
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
                          if (_ridePhase == _RidePhase.headingToDestination)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.accentEmeraldLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Picked Up',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.accentEmerald,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.only(left: 28, top: 8, bottom: 8),
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
                          if (_ridePhase == _RidePhase.headingToDestination)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.cancelRed.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_formatRemainingDestinationDistance()} • ${_etaToDestinationMinutes}m',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.cancelRed,
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

          // 3. FLOATING CIRCULAR BACK (<) AND GPS TARGET BUTTONS ABOVE BOTTOM SHEET
          if (!_isSheetExpanded &&
              _ridePhase != _RidePhase.arrivedAtDestination) ...[
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

          // 4. DARKENED MAP SCRIM WHEN ARRIVED AT DESTINATION
          if (_ridePhase == _RidePhase.arrivedAtDestination)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.52),
              ),
            ),

          // 5. BOTTOM SHEET FOR ALL 4 RIDE PHASES
          Align(
            alignment: Alignment.bottomCenter,
            child: _ridePhase == _RidePhase.arrivedAtDestination
                ? _buildYouHaveArrivedSheet()
                : AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(28)),
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
                      child: switch (_ridePhase) {
                        _RidePhase.findingDriver =>
                          _buildFindingNearbyDriverSheet(),
                        _RidePhase.driverHeadingToPickup =>
                          _buildDriverHeadingSheet(isDelivery: isDelivery),
                        _RidePhase.headingToDestination =>
                          _buildHeadingToDestinationSheet(
                            isDelivery: isDelivery,
                          ),
                        _RidePhase.arrivedAtDestination =>
                          const SizedBox.shrink(),
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Top-down vehicle marker with unmistakable forward nose/windshield at top (North = 0 rad)
  Widget _buildTopDownTricycleMarker() {
    return Center(
      child: SizedBox(
        width: 40,
        height: 58,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Vehicle body shadow & chassis
            Container(
              width: 34,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
                border: Border.all(
                  color: const Color(0xFF1E293B),
                  width: 2.2,
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Front nose / headlights + dark curved windshield at TOP (front of vehicle)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Container(
                      width: 22,
                      height: 11,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F172A),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(10),
                          bottomLeft: Radius.circular(3),
                          bottomRight: Radius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  // Center emerald canopy with forward navigation arrow pointing UP (front)
                  Container(
                    width: 24,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppTheme.accentEmerald,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.navigation_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                  // Rear bumper / tail lights at BOTTOM
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Container(
                      width: 20,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(3),
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

  // "Finding you a nearby driver..." Bottom Sheet
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

  // Collapsed & Expanded Bottom Sheet: "Driver is heading to your location..."
  Widget _buildDriverHeadingSheet({required bool isDelivery}) {
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
            const Text(
              'Driver is heading to your location...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.primarySlate,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Driver will arrive in $_etaToPassengerMinutes min... (${_distanceToPassengerMeters.toStringAsFixed(0)}m away)',
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
            const SizedBox(height: 10),
            // Quick action chip to board immediately if desired
            Align(
              alignment: Alignment.center,
              child: InkWell(
                onTap: _beginHeadingToDestinationPhase,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.accentEmeraldLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.directions_run_rounded,
                        size: 14,
                        color: AppTheme.accentEmerald,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Board Tricycle Now ➔ Start Trip to Destination',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentEmerald,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 14),
            _buildDriverProfileRow(),
            if (_isSheetExpanded) ...[
              _buildExpandedTripAndFareSection(
                isDelivery: isDelivery,
                showCancelButton: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // "Heading to destination..." (Passenger is on board traveling to designated location)
  Widget _buildHeadingToDestinationSheet({required bool isDelivery}) {
    final double progress = _destinationRoutePath.length > 1
        ? (_currentDestinationIndex / (_destinationRoutePath.length - 1))
            .clamp(0.05, 1.0)
        : 0.5;

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
            InkWell(
              onTap: () => setState(() => _isSheetExpanded = !_isSheetExpanded),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Title: "Heading to destination..."
            const Text(
              'Heading to destination...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.primarySlate,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),

            // Subtitle + Live Remaining Distance
            Text(
              'Will arrive at the destination in $_etaToDestinationMinutes mins... (${_formatRemainingDestinationDistance()} left)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
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

            const SizedBox(height: 12),

            // Live Distance Progress Bar so passenger sees how far or near they are while on travel
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.accentEmeraldLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.assistant_navigation,
                            size: 16,
                            color: AppTheme.accentEmerald,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Distance left: ${_formatRemainingDestinationDistance()}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primarySlate,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: _triggerArrivedAtDestinationPhase,
                        child: const Text(
                          'Arrive Now ➔',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.accentEmerald,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.white,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.accentEmerald,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 14),

            _buildDriverProfileRow(),

            if (_isSheetExpanded) ...[
              _buildExpandedTripAndFareSection(
                isDelivery: isDelivery,
                showCancelButton: false,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // "You have arrived!" Modal Sheet with Floating Red Location Badge,
  // 3 Trip Metrics (Duration, Distance, Avg. Speed), 5 Mood Emojis, and "Finish" Button
  Widget _buildYouHaveArrivedSheet() {
    final parts = widget.dropoffPoint.name.split(', ');
    final destinationTitle = parts.first;
    final destinationSubtitle = parts.length > 1
        ? parts.sublist(1).join(', ')
        : '${widget.dropoffPoint.name}, Laoag City, Ilocos Norte';

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 52, 22, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 28,
                offset: Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'You have arrived!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primarySlate,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: Colors.grey.shade200),
                const SizedBox(height: 16),
                Text(
                  destinationTitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primarySlate,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  destinationSubtitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),

                // 3-Column Metrics Card: Duration | Distance | Avg. Speed
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildArrivalMetricColumn(
                        icon: Icons.access_time_rounded,
                        value: '$_totalTripDurationMinutes mins',
                        label: 'Duration',
                      ),
                      _buildArrivalMetricColumn(
                        icon: Icons.location_on_outlined,
                        value:
                            '${_totalTripDistanceKm.toStringAsFixed(1)} km',
                        label: 'Distance',
                      ),
                      _buildArrivalMetricColumn(
                        icon: Icons.speed_rounded,
                        value: '22 km/h',
                        label: 'Avg. Speed',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // "How was your mood during this trip?" Card with 5 Mood Faces
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'How was your mood during this trip?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primarySlate,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(5, (index) {
                          final bool isSelected = _selectedMoodIndex == index;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedMoodIndex = index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? AppTheme.accentEmerald
                                    : const Color(0xFFE0E0E0),
                              ),
                              child: CustomPaint(
                                painter: _MoodFacePainter(
                                  moodIndex: index,
                                  faceColor: Colors.white,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Green Pill "Finish" Button -> Opens Rate Driver Flow
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _openPostTripRateDriverFlow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentEmerald,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Finish',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Floating Red Circular Location Pin Straddling Top Edge
        Positioned(
          top: -38,
          child: Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.cancelRed,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.location_on_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildArrivalMetricColumn({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFEEEEEE), width: 1.5),
          ),
          child: Icon(icon, color: AppTheme.primarySlate, size: 22),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
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
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDriverProfileRow() {
    return Row(
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
        _buildGreenOutlinedIconButton(
          icon: Icons.chat_bubble_outline_rounded,
          tooltip: 'Chat with Driver',
          onTap: _openDriverChatScreen,
        ),
        const SizedBox(width: 10),
        _buildGreenOutlinedIconButton(
          icon: Icons.phone_outlined,
          tooltip: 'Call Driver',
          onTap: _openDriverVoiceCallScreen,
        ),
      ],
    );
  }

  Widget _buildExpandedTripAndFareSection({
    required bool isDelivery,
    required bool showCancelButton,
  }) {
    final fb = widget.fareBreakdown;
    final double grossFare = fb.baseFare + fb.distanceFare;

    return Column(
      children: [
        const SizedBox(height: 16),
        Divider(height: 1, color: Colors.grey.shade200),
        const SizedBox(height: 14),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        if (showCancelButton) ...[
          const SizedBox(height: 16),
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
      ],
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

// Custom Painter for the 5 Expressive Mood Faces ("How was your mood during this trip?")
class _MoodFacePainter extends CustomPainter {
  final int moodIndex; // 0 = Very Sad, 1 = Sad, 2 = Neutral, 3 = Happy, 4 = Beaming
  final Color faceColor;

  const _MoodFacePainter({
    required this.moodIndex,
    required this.faceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final eyePaint = Paint()
      ..color = faceColor
      ..style = PaintingStyle.fill;

    final mouthPaint = Paint()
      ..color = faceColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final double w = size.width;
    final double h = size.height;

    // Eyes
    canvas.drawCircle(Offset(w * 0.36, h * 0.38), 3.0, eyePaint);
    canvas.drawCircle(Offset(w * 0.64, h * 0.38), 3.0, eyePaint);

    // Mouth based on moodIndex
    final path = ui.Path();
    switch (moodIndex) {
      case 0: // Deep frown
        path.moveTo(w * 0.30, h * 0.70);
        path.quadraticBezierTo(w * 0.50, h * 0.52, w * 0.70, h * 0.70);
        canvas.drawPath(path, mouthPaint);
      case 1: // Slight frown
        path.moveTo(w * 0.32, h * 0.67);
        path.quadraticBezierTo(w * 0.50, h * 0.58, w * 0.68, h * 0.67);
        canvas.drawPath(path, mouthPaint);
      case 2: // Neutral straight line
        canvas.drawLine(
          Offset(w * 0.33, h * 0.64),
          Offset(w * 0.67, h * 0.64),
          mouthPaint,
        );
      case 3: // Happy smile (default selected)
        path.moveTo(w * 0.30, h * 0.58);
        path.quadraticBezierTo(w * 0.50, h * 0.74, w * 0.70, h * 0.58);
        canvas.drawPath(path, mouthPaint);
      default: // Very Happy / Beaming open smile
        final openSmilePaint = Paint()
          ..color = faceColor
          ..style = PaintingStyle.fill;
        path.moveTo(w * 0.28, h * 0.56);
        path.quadraticBezierTo(w * 0.50, h * 0.78, w * 0.72, h * 0.56);
        path.close();
        canvas.drawPath(path, openSmilePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MoodFacePainter oldDelegate) =>
      oldDelegate.moodIndex != moodIndex || oldDelegate.faceColor != faceColor;
}

// ============================================================================
// POST-TRIP DRIVER RATING SCREEN ("How was the driver?")
// ============================================================================
class _RateDriverScreen extends StatefulWidget {
  final Map<String, String> driverData;
  final FareBreakdown fareBreakdown;
  final String paymentMethod;

  const _RateDriverScreen({
    required this.driverData,
    required this.fareBreakdown,
    required this.paymentMethod,
  });

  @override
  State<_RateDriverScreen> createState() => _RateDriverScreenState();
}

class _RateDriverScreenState extends State<_RateDriverScreen> {
  int _selectedStars = 5;
  bool _showDetails = true;

  void _skipRating() {
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _submitRating() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AddTipForDriverScreen(
          driverData: widget.driverData,
          selectedStars: _selectedStars,
          paymentMethod: widget.paymentMethod,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fb = widget.fareBreakdown;
    final bool isDelivery = fb.tripType == TripType.pabiliPadala;
    final double grossFare = fb.baseFare + fb.distanceFare;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: _skipRating,
          icon: const Icon(Icons.close_rounded, color: AppTheme.primarySlate),
        ),
        actions: [
          TextButton(
            onPressed: _skipRating,
            child: const Text(
              'Skip',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.primarySlate,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    // Circular Driver Avatar
                    Container(
                      width: 104,
                      height: 104,
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
                        size: 62,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'How was the driver?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primarySlate,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Help PasadaNorte do better by rating this trip',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Divider(height: 1, color: Colors.grey.shade200),
                    const SizedBox(height: 22),

                    // 5 Interactive Star Icons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final int starNumber = index + 1;
                        final bool isFilled = starNumber <= _selectedStars;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedStars = starNumber),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                              isFilled
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              size: 48,
                              color: isFilled
                                  ? const Color(0xFFFF9800)
                                  : const Color(0xFFBDBDBD),
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 24),

                    if (_showDetails) ...[
                      // Ride & Payment Card
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFEEEEEE)),
                        ),
                        child: Column(
                          children: [
                            _buildDetailLine(
                              'Ride',
                              isDelivery
                                  ? 'PasadaNorte Pa-Deliver'
                                  : 'PasadaNorte Tricycle',
                            ),
                            const SizedBox(height: 12),
                            _buildDetailLine(
                              'Payment',
                              widget.paymentMethod.split(' (').first,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Trip Fare / Discounts / Total Paid Card
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFEEEEEE)),
                        ),
                        child: Column(
                          children: [
                            _buildDetailLine(
                              'Trip Fare',
                              '₱${grossFare.toStringAsFixed(2)}',
                            ),
                            const SizedBox(height: 12),
                            _buildDetailLine(
                              'Discounts (20%)',
                              fb.discountAmount > 0
                                  ? '- ₱${fb.discountAmount.toStringAsFixed(2)}'
                                  : '₱0.00',
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              child: Divider(
                                height: 1,
                                color: Colors.grey.shade200,
                              ),
                            ),
                            _buildDetailLine(
                              'Total Paid',
                              '₱${fb.finalFare.toStringAsFixed(2)}',
                              isBold: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    TextButton(
                      onPressed: () =>
                          setState(() => _showDetails = !_showDetails),
                      child: Text(
                        _showDetails ? 'Hide details' : 'Show details',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentEmerald,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom "Skip" & "Give Rate" Buttons
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _skipRating,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentEmeraldLight,
                          foregroundColor: AppTheme.accentEmerald,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _submitRating,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentEmerald,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Give Rate',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
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
    );
  }

  Widget _buildDetailLine(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 15.5 : 14.5,
            fontWeight: FontWeight.w800,
            color: AppTheme.primarySlate,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// ADD TIP FOR DRIVER SCREEN ("Wow 5 Stars!")
// ============================================================================
class _AddTipForDriverScreen extends StatefulWidget {
  final Map<String, String> driverData;
  final int selectedStars;
  final String paymentMethod;

  const _AddTipForDriverScreen({
    required this.driverData,
    required this.selectedStars,
    required this.paymentMethod,
  });

  @override
  State<_AddTipForDriverScreen> createState() => _AddTipForDriverScreenState();
}

class _AddTipForDriverScreenState extends State<_AddTipForDriverScreen> {
  static const List<int> _presetTips = [5, 10, 15, 20, 25, 30, 50, 75, 100];
  int _selectedTipAmount = 25;

  void _completeFeedbackFlow() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const _RideFeedbackCompletedScreen(),
      ),
    );
  }

  Future<void> _promptCustomTipAmount() async {
    final controller =
        TextEditingController(text: _selectedTipAmount.toString());
    final customVal = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Enter Custom Tip (₱)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.primarySlate,
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            prefixText: '₱ ',
            hintText: 'e.g. 40',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              Navigator.pop(ctx, parsed);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (customVal != null && customVal > 0 && mounted) {
      setState(() {
        _selectedTipAmount = customVal;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: _completeFeedbackFlow,
          icon: const Icon(Icons.close_rounded, color: AppTheme.primarySlate),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 104,
                      height: 104,
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
                        size: 62,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Wow ${widget.selectedStars} Stars!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primarySlate,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Would you like to add a tip to make your\ndriver's day?",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Divider(height: 1, color: Colors.grey.shade200),
                    const SizedBox(height: 20),

                    // 3x3 Grid of Selectable Tip Pills
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _presetTips.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 2.15,
                      ),
                      itemBuilder: (context, index) {
                        final amount = _presetTips[index];
                        final isSelected = _selectedTipAmount == amount;
                        return InkWell(
                          onTap: () =>
                              setState(() => _selectedTipAmount = amount),
                          borderRadius: BorderRadius.circular(28),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.accentEmerald
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.accentEmerald
                                    : const Color(0xFFE0E0E0),
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '₱${amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected
                                      ? Colors.white
                                      : AppTheme.primarySlate,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: _promptCustomTipAmount,
                      child: const Text(
                        'Enter custom amount',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentEmerald,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Divider(height: 1, color: Colors.grey.shade200),
                    const SizedBox(height: 18),
                    Text(
                      'Tip will be charged from your ${widget.paymentMethod.split(' (').first}.\n100% of the tip goes to drivers.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom "Skip" & "Pay Tip" Buttons
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _completeFeedbackFlow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentEmeraldLight,
                          foregroundColor: AppTheme.accentEmerald,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _completeFeedbackFlow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentEmerald,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Pay Tip',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
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
    );
  }
}

// ============================================================================
// RIDE COMPLETED FEEDBACK SCREEN ("Thanks for your feedback!")
// ============================================================================
class _RideFeedbackCompletedScreen extends StatelessWidget {
  const _RideFeedbackCompletedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          icon: const Icon(Icons.close_rounded, color: AppTheme.primarySlate),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.accentEmerald,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 46,
                        ),
                      ),
                      const SizedBox(height: 26),
                      const Text(
                        'Thanks for your feedback!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primarySlate,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'See you on your next trip!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade100)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentEmerald,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
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

// ============================================================================
// DRIVER INFORMATION + PASADANORTE 4-ANGLE VEHICLE PHOTOS
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: 20,
                      ),
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 16,
                      ),
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
                            'Member Since',
                            driverData['memberSince']!,
                          ),
                          const SizedBox(height: 14),
                          _buildDetailRow(
                            'Tricycle Model',
                            driverData['vehicleModel']!,
                          ),
                          const SizedBox(height: 14),
                          _buildDetailRow('Color', driverData['color']!),
                          const SizedBox(height: 14),
                          _buildDetailRow(
                            'MTOP Body Number',
                            driverData['bodyNumber']!,
                          ),
                          const SizedBox(height: 14),
                          _buildDetailRow(
                            'Plate Number',
                            driverData['plateNumber']!,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
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
// IN-APP CHAT WITH DRIVER
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
                        horizontal: 16,
                        vertical: 12,
                      ),
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
                          horizontal: 16,
                          vertical: 12,
                        ),
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
// IN-APP VOICE CALL SCREEN
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
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
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
// CANCEL RIDE REASON & CANCELED CONFIRMATION
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
