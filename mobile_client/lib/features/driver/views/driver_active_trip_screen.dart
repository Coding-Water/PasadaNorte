import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/driver_stats_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/toda_queue_service.dart';
import '../../../core/theme/app_theme.dart';

enum DriverTripStage {
  enRouteToPickup,
  arrivedAtPickup,
  inTransitToDropoff,
  tripCompleted,
}

class DriverActiveTripScreen extends StatefulWidget {
  final String driverName;
  final String? driverPhotoUrl;
  final String passengerName;
  final String passengerCategory;
  final LocationPoint pickupPoint;
  final LocationPoint dropoffPoint;
  final double distanceKm;
  final double regularFare;
  final double discountedFare;
  final String paymentMethod;

  const DriverActiveTripScreen({
    super.key,
    required this.driverName,
    this.driverPhotoUrl = 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?fit=crop&w=150&q=80',
    this.passengerName = 'Maria Clara Santos',
    this.passengerCategory = 'STUDENT (20% STATUTORY DISCOUNT)',
    this.pickupPoint = const LocationPoint(
      latitude: 18.194096,
      longitude: 120.595856,
      name: 'Laoag Central Terminal & Public Market',
      zoneCode: 'Z01',
    ),
    this.dropoffPoint = const LocationPoint(
      latitude: 18.203595,
      longitude: 120.593643,
      name: 'MMSU Laoag Campus (CTE / CIT Gate)',
      zoneCode: 'Z02',
    ),
    this.distanceKm = 1.25,
    this.regularFare = 20.00,
    this.discountedFare = 16.00,
    this.paymentMethod = 'CASH TO COLLECT',
  });

  @override
  State<DriverActiveTripScreen> createState() => _DriverActiveTripScreenState();
}

class _DriverActiveTripScreenState extends State<DriverActiveTripScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  static const double _navigationZoom = 17.5;
  DriverTripStage _currentStage = DriverTripStage.enRouteToPickup;
  bool _cashReceived = true;
  bool _isTurnByTurnVoiceMuted = false;

  // Dynamic route segments: Traversed route trail left behind vs active ahead route
  List<LatLng> get _traversedPolyline {
    if (_currentRoutePolyline.isEmpty) return [];
    final endIndex = min(_currentPolylineIndex + 1, _currentRoutePolyline.length);
    final points = List<LatLng>.from(_currentRoutePolyline.sublist(0, endIndex));
    if (points.isNotEmpty && points.last != _currentDriverLocation) {
      points.add(_currentDriverLocation);
    }
    return points;
  }

  List<LatLng> get _remainingPolyline {
    if (_currentRoutePolyline.isEmpty) return [];
    final points = <LatLng>[_currentDriverLocation];
    final nextIndex = min(_currentPolylineIndex + 1, _currentRoutePolyline.length);
    if (nextIndex < _currentRoutePolyline.length) {
      points.addAll(_currentRoutePolyline.sublist(nextIndex));
    }
    return points;
  }

  // Periodic telemetry timer
  Timer? _telemetryTimer;

  // Driving simulation and auto-follow state (RA 10913 Anti-Distracted Driving Hands-Free HUD)
  Timer? _navigationTimer;
  int _currentPolylineIndex = 0;
  bool _isAutoFollowLocked = true;
  Timer? _autoFollowResumeTimer;
  bool _isOffRoute = false;
  bool _isRerouting = false;
  String _rerouteBannerMessage = '';
  String _topNotificationMessage = '';
  Timer? _topNotificationTimer;

  void _showTopNotification(String message) {
    _topNotificationTimer?.cancel();
    setState(() {
      _topNotificationMessage = message;
    });
    _topNotificationTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _topNotificationMessage = '';
        });
      }
    });
  }

  // Driver simulated live position
  late LatLng _currentDriverLocation;
  List<LatLng> _currentRoutePolyline = [];

  // Chat conversation
  final List<Map<String, String>> _chatMessages = [
    {
      'sender': 'passenger',
      'text': 'Hello po manong driver, waiting po ako near terminal gate 1.',
      'time': 'Just now',
    },
  ];

  @override
  void initState() {
    super.initState();
    // Driver starts on downtown street grid ~300 meters away from market
    _currentDriverLocation = LatLng(
      widget.pickupPoint.latitude + 0.0024,
      widget.pickupPoint.longitude - 0.0020,
    );
    _buildStageRoute();

    // Broadcast GPS telemetry every 4 seconds to Supabase
    _telemetryTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      SupabaseService.broadcastDriverTelemetry(
        rideId: 'ACTIVE_RIDE_${widget.driverName.hashCode.abs()}',
        latitude: _currentDriverLocation.latitude,
        longitude: _currentDriverLocation.longitude,
        heading: 45.0,
        stage: _currentStage.name,
      );
    });
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    _navigationTimer?.cancel();
    _autoFollowResumeTimer?.cancel();
    _topNotificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _launchExternalNavigation() async {
    final target = _currentStage == DriverTripStage.enRouteToPickup
        ? widget.pickupPoint
        : widget.dropoffPoint;
    final uri = Uri.parse('google.navigation:q=${target.latitude},${target.longitude}&mode=d');
    final webUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${target.latitude},${target.longitude}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening navigation to ${target.name}...'),
            backgroundColor: AppTheme.accentEmerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _triggerSosEmergency() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.emergency_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 10),
            Text(
              'EMERGENCY SOS',
              style: TextStyle(color: AppTheme.primarySlate, fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Text(
          'Broadcast distress beacon immediately to Laoag PNP Headquarters & TODA Central Dispatch with your live GPS coordinates?',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await SupabaseService.broadcastSosAlert(
                driverName: widget.driverName,
                latitude: _currentDriverLocation.latitude,
                longitude: _currentDriverLocation.longitude,
                reason: 'DRIVER_PANIC_BUTTON_ACTIVE_TRIP',
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🚨 SOS ALERT SENT: Laoag PNP & TODA Dispatch alerted with your GPS location!'),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 5),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('BROADCAST SOS', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Future<void> _buildStageRoute() async {
    final LocationPoint origin;
    final LocationPoint destination;

    if (_currentStage == DriverTripStage.enRouteToPickup) {
      origin = LocationPoint(
        latitude: _currentDriverLocation.latitude,
        longitude: _currentDriverLocation.longitude,
        name: 'Driver Live GPS',
      );
      destination = widget.pickupPoint;
    } else {
      origin = widget.pickupPoint;
      destination = widget.dropoffPoint;
    }

    try {
      final routeResult = await LocationService.fetchRoadRoute(origin, destination);
      if (mounted && routeResult.polylinePoints.length >= 2) {
        setState(() {
          _currentRoutePolyline = routeResult.polylinePoints;
          _currentPolylineIndex = 0;
        });
        _startNavigationDrive();
        return;
      }
    } catch (_) {}

    // Fallback: Smart Laoag street grid path (never cuts through buildings)
    if (mounted) {
      setState(() {
        _currentRoutePolyline = [
          origin.latLng,
          LatLng(origin.latitude, destination.longitude),
          destination.latLng,
        ];
        _currentPolylineIndex = 0;
      });
      _startNavigationDrive();
    }
  }

  void _startNavigationDrive() {
    _navigationTimer?.cancel();
    if (_currentStage == DriverTripStage.arrivedAtPickup ||
        _currentStage == DriverTripStage.tripCompleted) {
      return;
    }
    if (_currentRoutePolyline.isEmpty) return;

    // Advance smoothly across ~25 steps
    final int stepIncrement = max(1, (_currentRoutePolyline.length / 25).ceil());

    _navigationTimer = Timer.periodic(const Duration(milliseconds: 650), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_isRerouting) return;

      if (_currentPolylineIndex < _currentRoutePolyline.length - 1) {
        setState(() {
          _currentPolylineIndex = min(
            _currentRoutePolyline.length - 1,
            _currentPolylineIndex + stepIncrement,
          );
          _currentDriverLocation = _currentRoutePolyline[_currentPolylineIndex];
        });

        // 1. AUTO-FOLLOW CAMERA: Automatically glides the camera hands-free
        if (_isAutoFollowLocked) {
          _mapController.move(_currentDriverLocation, _navigationZoom);
        }

        // 3. AUTO-ROUTE SENTINEL: Detect if vehicle strays off-route (> 38m)
        final offRouteDist = LocationService.distanceToPolylineMeters(
          _currentDriverLocation,
          _currentRoutePolyline,
        );
        if (offRouteDist > 38.0 && !_isRerouting) {
          _triggerDynamicReroute(reason: 'Road repair or detour detected');
        }
      } else {
        timer.cancel();
        if (_currentStage == DriverTripStage.enRouteToPickup) {
          _onSlideActionTriggered();
        } else if (_currentStage == DriverTripStage.inTransitToDropoff) {
          _onSlideActionTriggered();
        }
      }
    });
  }

  Future<void> _triggerDynamicReroute({String reason = 'Traffic or road obstruction'}) async {
    if (_isRerouting) return;
    setState(() {
      _isRerouting = true;
      _isOffRoute = true;
      _rerouteBannerMessage = '⚠️ DETOUR DETECTED ($reason) • Auto-Rerouting...';
    });

    final destination = _currentStage == DriverTripStage.enRouteToPickup
        ? widget.pickupPoint
        : widget.dropoffPoint;

    final origin = LocationPoint(
      latitude: _currentDriverLocation.latitude,
      longitude: _currentDriverLocation.longitude,
      name: 'Driver Current GPS',
    );

    try {
      final newRoute = await LocationService.fetchRoadRoute(origin, destination);
      if (mounted && newRoute.polylinePoints.length >= 2) {
        setState(() {
          _currentRoutePolyline = newRoute.polylinePoints;
          _currentPolylineIndex = 0;
          _isRerouting = false;
          _isOffRoute = false;
          _rerouteBannerMessage = '✓ Route Recalculated (${newRoute.distanceKm} km via alternate Laoag street)';
        });
        _startNavigationDrive();
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() => _rerouteBannerMessage = '');
        });
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isRerouting = false;
        _isOffRoute = false;
        _rerouteBannerMessage = '✓ Continuing navigation along alternate road';
      });
      _startNavigationDrive();
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _rerouteBannerMessage = '');
      });
    }
  }

  void _simulateDetour() {
    // Deliberately shift driver position 45m laterally onto adjacent parallel Laoag street
    // (e.g. detour from J.P. Rizal to A. Mabini / F.R. Castro Ave due to road repair)
    setState(() {
      _currentDriverLocation = LatLng(
        _currentDriverLocation.latitude + 0.00042,
        _currentDriverLocation.longitude - 0.00038,
      );
    });
    _triggerDynamicReroute(reason: 'Road repair / traffic jam on primary street');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Simulated Detour: Driver took alternate road due to road repair. Auto-rerouting triggered!'),
        backgroundColor: Colors.amber,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onSlideActionTriggered() {
    setState(() {
      if (_currentStage == DriverTripStage.enRouteToPickup) {
        _navigationTimer?.cancel();
        _currentStage = DriverTripStage.arrivedAtPickup;
        _currentDriverLocation = widget.pickupPoint.latLng;
        _buildStageRoute();
        _showTopNotification('Notified Passenger: "Your TODA driver has arrived at pickup."');
      } else if (_currentStage == DriverTripStage.arrivedAtPickup) {
        _currentStage = DriverTripStage.inTransitToDropoff;
        _buildStageRoute();
        _mapController.move(_currentDriverLocation, _navigationZoom);
        _showTopNotification('Trip Started: GPS meter running to ${widget.dropoffPoint.name}.');
      } else if (_currentStage == DriverTripStage.inTransitToDropoff) {
        _navigationTimer?.cancel();
        _currentStage = DriverTripStage.tripCompleted;
        _showFareSettlementModal();
      }
    });
  }

  void _openPassengerCallModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
              const SizedBox(height: 20),
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF4F46E5),
                ),
                child: const Center(
                  child: Text(
                    'MC',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                widget.passengerName,
                style: const TextStyle(
                  color: AppTheme.primarySlate,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '+63 917 849 2038 • Passenger in Laoag',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primarySlate,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Simulated Call: Connected to passenger.'),
                            backgroundColor: AppTheme.accentEmerald,
                          ),
                        );
                      },
                      icon: const Icon(Icons.call_rounded, size: 20),
                      label: const Text('Voice Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentEmerald,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPassengerChatModal() {
    final TextEditingController textCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              height: 480,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
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
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF4F46E5),
                            ),
                            child: const Center(
                              child: Text(
                                'MC',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.passengerName,
                                style: const TextStyle(
                                  color: AppTheme.primarySlate,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                'In-Trip Passenger Chat',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(Icons.close_rounded, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                  Divider(color: Colors.grey.shade200, height: 18),
                  // Chat Messages List
                  Expanded(
                    child: ListView.builder(
                      itemCount: _chatMessages.length,
                      itemBuilder: (context, index) {
                        final msg = _chatMessages[index];
                        final isDriver = msg['sender'] == 'driver';
                        return Align(
                          alignment: isDriver
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isDriver
                                   ? AppTheme.accentEmerald
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              crossAxisAlignment: isDriver
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg['text'] ?? '',
                                  style: TextStyle(
                                    color: isDriver ? Colors.white : AppTheme.primarySlate,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  msg['time'] ?? '',
                                  style: TextStyle(
                                    color: isDriver ? Colors.white70 : Colors.grey.shade500,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Ilokano Quick Canned Replies
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildQuickReplyChip(
                          'Dadditoyakon!',
                          onTap: () {
                            setModalState(() {
                              _chatMessages.add({
                                'sender': 'driver',
                                'text': 'Dadditoyakon dita pickup terminal! (I am here!)',
                                'time': 'Now',
                              });
                            });
                          },
                        ),
                        _buildQuickReplyChip(
                          'On the way 🛺',
                          onTap: () {
                            setModalState(() {
                              _chatMessages.add({
                                'sender': 'driver',
                                'text': 'On the way na po ako dita location niyo.',
                                'time': 'Now',
                              });
                            });
                          },
                        ),
                        _buildQuickReplyChip(
                          'Waiting at gate',
                          onTap: () {
                            setModalState(() {
                              _chatMessages.add({
                                'sender': 'driver',
                                'text': 'Naka-park po ako near main gate.',
                                'time': 'Now',
                              });
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Input Bar
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: textCtrl,
                          style: const TextStyle(color: AppTheme.primarySlate, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Reply to passenger...',
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          if (textCtrl.text.trim().isNotEmpty) {
                            setModalState(() {
                              _chatMessages.add({
                                'sender': 'driver',
                                'text': textCtrl.text.trim(),
                                'time': 'Now',
                              });
                            });
                            textCtrl.clear();
                          }
                        },
                        icon: const Icon(
                          Icons.send_rounded,
                          color: AppTheme.accentEmerald,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickReplyChip(String text, {required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 6),
      child: ActionChip(
        label: Text(text, style: const TextStyle(fontSize: 11.5, color: AppTheme.primarySlate, fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFFF1F5F9),
        side: BorderSide(color: Colors.grey.shade300),
        onPressed: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  void _showFareSettlementModal() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
                  const SizedBox(height: 12),
                  // Green Circle Success Checkmark
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.accentEmeraldLight,
                      border: Border.all(color: AppTheme.accentEmerald, width: 2.2),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: AppTheme.accentEmerald,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Trip Completed!',
                    style: TextStyle(
                      color: AppTheme.primarySlate,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Arrived at ${widget.dropoffPoint.name}',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                  ),
                  const SizedBox(height: 12),

                  // Amount to Collect Card (Clean Light High-Contrast Card)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'TOTAL FARE TO COLLECT',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₱${widget.discountedFare.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: AppTheme.primarySlate,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Divider(color: Colors.grey.shade200, height: 1),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Base First Km (City Ord. 2023-005)',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                            Text(
                              '₱${widget.regularFare.toStringAsFixed(2)}',
                              style: const TextStyle(color: AppTheme.primarySlate, fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Student / PWD Discount (20%)',
                              style: TextStyle(color: AppTheme.accentEmerald, fontSize: 12),
                            ),
                            Text(
                              '- ₱${(widget.regularFare - widget.discountedFare).toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppTheme.accentEmerald,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // TODA Terminal Re-entry Information Card
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.pin_drop_rounded, color: Color(0xFFB45309), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'NEAREST TODA PILA AFTER DROPOFF',
                                style: TextStyle(
                                  color: Color(0xFF92400E),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${TodaQueueService.findNearestTerminal(widget.dropoffPoint.latitude, widget.dropoffPoint.longitude).terminal.name} (${(TodaQueueService.findNearestTerminal(widget.dropoffPoint.latitude, widget.dropoffPoint.longitude).distanceMeters / 1000).toStringAsFixed(2)} km)',
                                style: const TextStyle(
                                  color: Color(0xFF78350F),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                  // Cash Received Checkbox
                  InkWell(
                    onTap: () {
                      setModalState(() {
                        _cashReceived = !_cashReceived;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            _cashReceived
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            color: AppTheme.accentEmerald,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'I have collected ₱${widget.discountedFare.toStringAsFixed(2)} cash payment from passenger',
                              style: const TextStyle(color: AppTheme.primarySlate, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),
                  // Action 1: Confirm & Route to TODA Pila
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await _recordCompletedTrip();
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          _startReturnToPilaRoute();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentEmerald,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      icon: const Icon(Icons.turn_right_rounded, size: 20),
                      label: const Text(
                        'CONFIRM & ROUTE TO TODA PILA',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Action 2: Finish Trip Only (Take a Break / Go Offline)
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton(
                      onPressed: () async {
                        await _recordCompletedTrip();
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          Navigator.pop(context, false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Trip finalized! Standing by (Not queued in Toda Pila).'),
                              backgroundColor: AppTheme.primarySlate,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primarySlate,
                        side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'FINISH TRIP ONLY (TAKE A BREAK / OFFLINE)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _recordCompletedTrip() async {
    await DriverStatsService.recordTrip(
      fare: widget.discountedFare,
      passengerName: widget.passengerName,
      route: '${widget.pickupPoint.name} ➔ ${widget.dropoffPoint.name}',
      isCash: _cashReceived,
    );

    await SupabaseService.recordCompletedTrip(
      driverName: widget.driverName,
      fare: widget.discountedFare,
      distanceKm: widget.distanceKm,
      passengerName: widget.passengerName,
      paymentMethod: widget.paymentMethod,
      destination: widget.dropoffPoint.name,
    );
  }

  void _startReturnToPilaRoute() async {
    final nearest = TodaQueueService.findNearestTerminal(
      widget.dropoffPoint.latitude,
      widget.dropoffPoint.longitude,
    );

    _showTopNotification('🗺️ Routing to ${nearest.terminal.name} Pila • Auto-queuing inside 25m geofence...');

    setState(() {
      _currentStage = DriverTripStage.tripCompleted;
      _rerouteBannerMessage = '📍 Returning to ${nearest.terminal.name} Pila (${(nearest.distanceMeters / 1000).toStringAsFixed(2)} km)';
    });

    final origin = LocationPoint(
      latitude: _currentDriverLocation.latitude,
      longitude: _currentDriverLocation.longitude,
      name: 'Current Dropoff Location',
    );
    final destination = LocationPoint(
      latitude: nearest.terminal.centerPoint.latitude,
      longitude: nearest.terminal.centerPoint.longitude,
      name: nearest.terminal.name,
    );

    try {
      final routeRes = await LocationService.fetchRoadRoute(origin, destination);
      if (mounted && routeRes.polylinePoints.length >= 2) {
        setState(() {
          _currentRoutePolyline = routeRes.polylinePoints;
          _currentPolylineIndex = 0;
        });
      }
    } catch (_) {}

    _navigationTimer?.cancel();
    final int stepIncrement = max(1, (_currentRoutePolyline.length / 18).ceil());

    _navigationTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_currentPolylineIndex < _currentRoutePolyline.length - 1) {
        setState(() {
          _currentPolylineIndex = min(
            _currentRoutePolyline.length - 1,
            _currentPolylineIndex + stepIncrement,
          );
          _currentDriverLocation = _currentRoutePolyline[_currentPolylineIndex];
        });

        if (_isAutoFollowLocked) {
          _mapController.move(_currentDriverLocation, _navigationZoom);
        }

        final distToTerminal = LocationService.calculateDistanceInKm(
          _currentDriverLocation.latitude,
          _currentDriverLocation.longitude,
          nearest.terminal.centerPoint.latitude,
          nearest.terminal.centerPoint.longitude,
        ) * 1000.0;

        if (distToTerminal <= nearest.terminal.radiusMeters) {
          timer.cancel();
          _showTopNotification('✓ ENTERED PILA GEOFENCE (${distToTerminal.toStringAsFixed(0)}m <= 25m): Queued at Rank #1 in ${nearest.terminal.name}!');
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              Navigator.pop(context, true);
            }
          });
        }
      } else {
        timer.cancel();
        _showTopNotification('✓ Reached ${nearest.terminal.name}: Queued at Rank #1 in Digital Pila!');
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            Navigator.pop(context, true);
          }
        });
      }
    });
  }

  void _confirmEmergencyExit() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 26),
            SizedBox(width: 10),
            Text(
              'Cancel Active Dispatch?',
              style: TextStyle(color: AppTheme.primarySlate, fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Text(
          'Canceling an accepted ride will re-route the passenger to TODA Rank #2 driver and may affect your completion rate.',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Keep Driving', style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Dispatch'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // 1. Full-Bleed Map Canvas with Street Route
          Positioned.fill(
            bottom: 260,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentDriverLocation,
                initialZoom: _navigationZoom,
                onPositionChanged: (pos, hasGesture) {
                  if (hasGesture && _isAutoFollowLocked) {
                    setState(() {
                      _isAutoFollowLocked = false;
                    });
                    _autoFollowResumeTimer?.cancel();
                    _autoFollowResumeTimer = Timer(const Duration(seconds: 4), () {
                      if (mounted) {
                        setState(() {
                          _isAutoFollowLocked = true;
                        });
                        _mapController.move(_currentDriverLocation, _navigationZoom);
                      }
                    });
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                  userAgentPackageName: 'ph.laoag.pasadanorte',
                ),
                // Route Polylines: Traversed Trail Left Behind + Active Ahead Green Route
                PolylineLayer(
                  polylines: [
                    // 1. Traversed segment left behind (subtle blue-grey route trail)
                    if (_traversedPolyline.length >= 2) ...[
                      Polyline(
                        points: _traversedPolyline,
                        strokeWidth: 6.0,
                        color: Colors.blueGrey.shade200.withValues(alpha: 0.45),
                      ),
                      Polyline(
                        points: _traversedPolyline,
                        strokeWidth: 4.0,
                        color: Colors.blueGrey.shade400.withValues(alpha: 0.75),
                      ),
                    ],
                    // 2. Active remaining road route ahead of vehicle (vibrant emerald green)
                    if (_remainingPolyline.length >= 2) ...[
                      Polyline(
                        points: _remainingPolyline,
                        strokeWidth: 9.0,
                        color: (_isOffRoute ? Colors.amber.shade700 : AppTheme.accentEmerald).withValues(alpha: 0.35),
                      ),
                      Polyline(
                        points: _remainingPolyline,
                        strokeWidth: 5.5,
                        color: _isOffRoute ? Colors.amber.shade700 : AppTheme.accentEmerald,
                      ),
                    ],
                  ],
                ),
                MarkerLayer(
                  markers: [
                    // Pickup Marker
                    Marker(
                      point: widget.pickupPoint.latLng,
                      width: 52,
                      height: 52,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF064E3B),
                          border: Border.all(color: AppTheme.accentEmerald, width: 3),
                        ),
                        child: const Icon(
                          Icons.person_pin_circle_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                    // Dropoff Marker
                    Marker(
                      point: widget.dropoffPoint.latLng,
                      width: 52,
                      height: 52,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.shade900,
                          border: Border.all(color: Colors.redAccent, width: 3),
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                    // Driver Photo Marker with Verified TODA Badge & Amber Ring
                    Marker(
                      point: _currentDriverLocation,
                      width: 64,
                      height: 64,
                      child: _buildDriverPhotoMarker(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Top Floating Route Card (Passenger Clean White Architecture)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
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
                        // Pickup Location Row
                        Row(
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.accentEmerald,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.pickupPoint.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppTheme.primarySlate,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Zone 1 • J. P. Rizal St • Public Market TODA Station',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Dotted Line
                        Padding(
                          padding: const EdgeInsets.only(left: 6.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 2,
                              height: 14,
                              color: Colors.grey.shade300,
                            ),
                          ),
                        ),
                        // Dropoff Location Row
                        Row(
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.dropoffPoint.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppTheme.primarySlate,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Zone 2 • P. Gomez St • CTE/CIT • ${widget.distanceKm.toStringAsFixed(2)} km',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Ordinance Compliance Tag
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.accentEmeraldLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'LAOAG CITY ORD. 2023-005 • AUTOMATIC GPS FARE COMPUTATION',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.accentEmerald,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Auto-Follow / Hands-Free Safety HUD & Detour Recalculating Banner
                  if (_rerouteBannerMessage.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade900,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.alt_route_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _rerouteBannerMessage,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (!_isAutoFollowLocked)
                    GestureDetector(
                      onTap: () {
                        _autoFollowResumeTimer?.cancel();
                        setState(() => _isAutoFollowLocked = true);
                        _mapController.move(_currentDriverLocation, _navigationZoom);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade800,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'MAP MOVED • TAP TO RESUME AUTO-FOLLOW (AUTO IN 4s)',
                              style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.navigation_rounded, color: AppTheme.accentEmerald, size: 13),
                          SizedBox(width: 6),
                          Text(
                            'AUTO-FOLLOW: ACTIVE • HANDS-FREE SAFETY',
                            style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),

                  // Floating Quick Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // Exit / Cancel Button
                          _buildFloatingCircleBtn(
                            icon: Icons.close_rounded,
                            color: AppTheme.primarySlate,
                            onTap: _confirmEmergencyExit,
                          ),
                          const SizedBox(width: 8),
                          // SOS Emergency Panic Button
                          _buildFloatingCircleBtn(
                            icon: Icons.emergency_rounded,
                            color: Colors.red.shade600,
                            onTap: _triggerSosEmergency,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // Simulate Road Detour / Traffic Reroute
                          _buildFloatingCircleBtn(
                            icon: Icons.alt_route_rounded,
                            color: Colors.amber.shade800,
                            onTap: _simulateDetour,
                          ),
                          const SizedBox(width: 8),
                          // External Navigation (Google Maps Turn-by-Turn)
                          _buildFloatingCircleBtn(
                            icon: Icons.navigation_rounded,
                            color: const Color(0xFF2563EB),
                            onTap: _launchExternalNavigation,
                          ),
                          const SizedBox(width: 8),
                          // Turn-by-Turn Voice Toggle
                          _buildFloatingCircleBtn(
                            icon: _isTurnByTurnVoiceMuted
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            color: _isTurnByTurnVoiceMuted ? Colors.grey.shade400 : const Color(0xFFD97706),
                            onTap: () {
                              setState(() {
                                _isTurnByTurnVoiceMuted = !_isTurnByTurnVoiceMuted;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          // Re-center Compass Button
                          _buildFloatingCircleBtn(
                            icon: Icons.my_location_rounded,
                            color: _isAutoFollowLocked ? AppTheme.accentEmerald : Colors.amber.shade800,
                            onTap: () {
                              _autoFollowResumeTimer?.cancel();
                              setState(() => _isAutoFollowLocked = true);
                              _mapController.move(_currentDriverLocation, _navigationZoom);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 3. Bottom Driver Active Trip Sheet (Passenger Clean White Theme)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Trip Status & Stage Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getStageTitle(),
                              style: const TextStyle(
                                color: AppTheme.primarySlate,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _getStageSubtitle(),
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Text(
                          'PILA RANK #1',
                          style: TextStyle(
                            color: Color(0xFFB45309),
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),

                  Divider(color: Colors.grey.shade200, height: 20),

                  // Passenger Profile Row
                  Row(
                    children: [
                      // Avatar
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFE0E7FF),
                        ),
                        child: const Center(
                          child: Text(
                            'MC',
                            style: TextStyle(
                              color: Color(0xFF4338CA),
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.passengerName,
                              style: const TextStyle(
                                color: AppTheme.primarySlate,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 16),
                                const SizedBox(width: 3),
                                Text(
                                  '4.9 • 38 rides in Laoag',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accentEmeraldLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.passengerCategory,
                                style: const TextStyle(
                                  color: AppTheme.accentEmerald,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Outlined Chat Button
                      _buildOutlinedCircleBtn(
                        icon: Icons.chat_bubble_outline_rounded,
                        onTap: _openPassengerChatModal,
                      ),
                      const SizedBox(width: 10),
                      // Outlined Call Button
                      _buildOutlinedCircleBtn(
                        icon: Icons.phone_outlined,
                        onTap: _openPassengerCallModal,
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Upfront Fare & Payment Card (Passenger Light Card Style)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Calculated Upfront Fare (${widget.distanceKm.toStringAsFixed(2)} km)',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                            ),
                            Text(
                              '₱${widget.discountedFare.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppTheme.primarySlate,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Statutory Student Discount (20%)',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                            ),
                            Text(
                              '- ₱${(widget.regularFare - widget.discountedFare).toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppTheme.accentEmerald,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Divider(color: Colors.grey.shade200, height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Payment Method',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                            ),
                            Text(
                              widget.paymentMethod,
                              style: const TextStyle(
                                color: AppTheme.primarySlate,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. SIGNATURE JOYRIDE SLIDE-TO-CONFIRM BAR
                  _SlideToConfirmWidget(
                    text: _getSliderLabel(),
                    onConfirmed: _onSlideActionTriggered,
                  ),
                ],
              ),
            ),
          ),

          // 5. Signature Top Notification Banner (Overhead HUD)
          if (_topNotificationMessage.isNotEmpty)
            Positioned(
              top: 14,
              left: 16,
              right: 16,
              child: SafeArea(
                child: Material(
                  elevation: 12,
                  borderRadius: BorderRadius.circular(18),
                  color: AppTheme.accentEmerald,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.accentEmerald,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _topNotificationMessage,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              letterSpacing: 0.2,
                            ),
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
    );
  }

  String _getStageTitle() {
    switch (_currentStage) {
      case DriverTripStage.enRouteToPickup:
        return 'En Route to Pickup';
      case DriverTripStage.arrivedAtPickup:
        return 'Arrived at Pickup';
      case DriverTripStage.inTransitToDropoff:
        return 'En Route to Destination';
      case DriverTripStage.tripCompleted:
        return 'Arrived at Destination';
    }
  }

  String _getStageSubtitle() {
    switch (_currentStage) {
      case DriverTripStage.enRouteToPickup:
        return 'Arriving in ~2 mins • 450m from rider';
      case DriverTripStage.arrivedAtPickup:
        return 'Waiting for Maria Clara Santos to board';
      case DriverTripStage.inTransitToDropoff:
        return 'Heading to MMSU Laoag Campus • ${widget.distanceKm.toStringAsFixed(2)} km';
      case DriverTripStage.tripCompleted:
        return 'Prepare to collect cash payment';
    }
  }

  String _getSliderLabel() {
    switch (_currentStage) {
      case DriverTripStage.enRouteToPickup:
        return 'SLIDE WHEN ARRIVED AT PICKUP';
      case DriverTripStage.arrivedAtPickup:
        return 'SLIDE TO START TRIP';
      case DriverTripStage.inTransitToDropoff:
        return 'SLIDE TO COMPLETE TRIP';
      case DriverTripStage.tripCompleted:
        return 'TRIP COMPLETED';
    }
  }

  Widget _buildDriverPhotoMarker() {
    final photoUrl = widget.driverPhotoUrl ??
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?fit=crop&w=150&q=80';

    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Driver Avatar Container with Amber Border and Elevation Shadow
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: const Color(0xFFF59E0B), width: 3.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 1.5,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.network(
                photoUrl,
                fit: BoxFit.cover,
                width: 52,
                height: 52,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0F766E), Color(0xFF065F46)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        widget.driverName.isNotEmpty ? widget.driverName[0].toUpperCase() : 'D',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: AppTheme.primarySlate,
                    child: const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Verified TODA Driver Badge (Bottom Right)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF064E3B),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4),
                ],
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: AppTheme.accentEmerald,
                size: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingCircleBtn({
    required IconData icon,
    required Color color,
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
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }

  Widget _buildOutlinedCircleBtn({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFF1F5F9),
          border: Border.all(color: AppTheme.accentEmerald.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Icon(icon, color: AppTheme.accentEmerald, size: 20),
      ),
    );
  }
}

// ============================================================================
// JOYRIDE-STYLE SLIDE-TO-CONFIRM WIDGET
// ============================================================================
class _SlideToConfirmWidget extends StatefulWidget {
  final String text;
  final VoidCallback onConfirmed;

  const _SlideToConfirmWidget({
    required this.text,
    required this.onConfirmed,
  });

  @override
  State<_SlideToConfirmWidget> createState() => _SlideToConfirmWidgetState();
}

class _SlideToConfirmWidgetState extends State<_SlideToConfirmWidget> {
  double _dragPosition = 0.0;
  static const double _thumbWidth = 52.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxDrag = constraints.maxWidth - _thumbWidth - 8.0;

        return Container(
          height: 60,
          decoration: BoxDecoration(
            color: AppTheme.accentEmerald,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentEmerald.withValues(alpha: 0.28),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Prompt Text
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 50),
                  child: Text(
                    widget.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              // Draggable Circle Thumb
              Positioned(
                left: 4.0 + _dragPosition,
                top: 4.0,
                bottom: 4.0,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _dragPosition = (_dragPosition + details.delta.dx)
                          .clamp(0.0, maxDrag);
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_dragPosition >= maxDrag * 0.75) {
                      // Confirmed!
                      widget.onConfirmed();
                    }
                    // Reset slider
                    setState(() {
                      _dragPosition = 0.0;
                    });
                  },
                  child: Container(
                    width: _thumbWidth,
                    height: _thumbWidth,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppTheme.accentEmerald,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
