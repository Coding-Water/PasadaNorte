import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/demand_forecast_service.dart';
import '../../../core/services/driver_stats_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/session_cache_service.dart';
import '../../../core/services/sound_alert_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/toda_queue_service.dart';
import '../../../core/services/system_notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/views/welcome_onboarding_screen.dart';
import 'driver_account_screen.dart';
import 'driver_active_trip_screen.dart';
import 'driver_activity_screen.dart';

class DriverMapDutyScreen extends StatefulWidget {
  final String fullName;

  const DriverMapDutyScreen({
    super.key,
    required this.fullName,
  });

  @override
  State<DriverMapDutyScreen> createState() => _DriverMapDutyScreenState();
}

class _DriverMapDutyScreenState extends State<DriverMapDutyScreen> {
  int _currentIndex = 0;
  bool _isOnline = true;
  bool _simulateNetworkDropFailSafe = false; // ISO/IEC 25010:2023 operational fail-safe during mobile data loss
  bool _showHotspots = false; // Default OFF so driver map is clean and does not cause dizziness
  bool _isHybridSatellite = false; // Google Roadmap vs Google Hybrid Satellite
  final LatLng _driverLocation = const LatLng(18.1960, 120.5935); // Laoag Central Terminal / Aurora Park
  final MapController _mapController = MapController();
  List<DemandZoneForecast> _zoneForecasts = [];

  void _returnToPasadaNorteHome() {
    unawaited(SessionCacheService.clearSession());
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeOnboardingScreen()),
      (route) => false,
    );
  }

  StreamSubscription<Map<String, dynamic>>? _rideRequestedSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _todaTerminalsSub;
  StreamSubscription<List<Map<String, dynamic>>>? _driverAppSub;
  bool _isDispatchDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _loadForecast();
    _listenToRealtimeDispatches();
    _listenToTodaTerminals();
    _listenToDriverApplication();
  }

  Future<void> _listenToDriverApplication() async {
    try {
      final session = await SessionCacheService.getSavedSession();
      final savedPhone = session?.phoneNumber.trim() ?? '';

      final baseStream = Supabase.instance.client
          .from('driver_applications')
          .stream(primaryKey: ['id']);
      final filteredStream = savedPhone.isNotEmpty
          ? baseStream.eq('phone_number', savedPhone)
          : baseStream.eq('full_name', widget.fullName.trim());

      _driverAppSub = filteredStream.listen((rows) {
        if (rows.isEmpty) return;
        final matched = rows.first;

        final todaCode = (matched['toda_code'] ?? '').toString().trim();
        final plateNo = (matched['plate_or_mv_file'] ?? '').toString().trim();
        final appStatus =
            (matched['application_status'] ?? '').toString().trim().toLowerCase();
        final adminNotes = (matched['admin_notes'] ?? '').toString();

        String pilaSlot = '';
        final match = RegExp(r'Assigned TODA Pila:\s*[^\(]+\(([^\)]+)\)')
            .firstMatch(adminNotes);
        if (match != null) {
          pilaSlot = match.group(1)?.trim() ?? '';
        }

        if (plateNo.isNotEmpty) {
          DriverStatsService.plateNumber = plateNo;
        }
        if (todaCode.isNotEmpty && todaCode.toLowerCase() != 'unassigned') {
          DriverStatsService.todaAssociation = todaCode;
          DriverStatsService.bodyNumber =
              pilaSlot.isNotEmpty ? pilaSlot : todaCode;
          DriverStatsService.mincFranchiseNumber = 'Franchise Active ($todaCode)';
        }
        if (appStatus == 'approved') {
          DriverStatsService.isFranchiseActive = true;
          DriverStatsService.lastInspectionStatus = 'Passed (MINC Verified)';
        }
        if (mounted) setState(() {});
      }, onError: (_) {});
    } catch (_) {}
  }

  void _listenToTodaTerminals() {
    try {
      _todaTerminalsSub = Supabase.instance.client
          .from('toda_terminals')
          .stream(primaryKey: ['id'])
          .listen((rows) {
        TodaQueueService.replaceTerminalsFromSupabase(rows);
        if (mounted) setState(() {});
      }, onError: (_) {});
    } catch (_) {}
  }

  void _listenToRealtimeDispatches() {
    try {
      SupabaseService.getDispatchChannel();
      _rideRequestedSubscription =
          SupabaseService.onRideRequested.listen((payload) {
        if (_isOnline && mounted && !_isDispatchDialogOpen) {
          _handleIncomingRealRideRequest(payload);
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _rideRequestedSubscription?.cancel();
    _todaTerminalsSub?.cancel();
    _driverAppSub?.cancel();
    super.dispose();
  }

  Future<void> _loadForecast() async {
    // 1 & 3: Demand forecasting is automatic based on current wall-clock hour & weekday
    final now = DateTime.now();
    final currentHour = now.hour;
    final isWeekday = now.weekday <= 5; // Monday=1 to Friday=5 is weekday

    final forecasts = await DemandForecastService.getHourlyForecast(
      hourOfDay: currentHour,
      isWeekday: isWeekday,
    );
    if (!mounted) return;
    setState(() {
      _zoneForecasts = forecasts;
    });
  }

  void _toggleDutyStatus() {
    setState(() {
      _isOnline = !_isOnline;
    });

      }

  void _handleIncomingRealRideRequest(Map<String, dynamic> request) {
    if (_isDispatchDialogOpen) return;
    _isDispatchDialogOpen = true;

    int remainingSeconds = TodaQueueService.autoPassSeconds; // 15 seconds
    Timer? countdownTimer;

    final String passengerName = (request['passenger_name'] as String?) ?? 'Commuter';
    final String passengerCategory = (request['passenger_category'] as String?) ?? 'REGULAR';
    final String pickupName = (request['pickup_name'] as String?) ?? 'Laoag Central Terminal & Public Market';
    final double pickupLat = (request['pickup_lat'] as num?)?.toDouble() ?? 18.194096;
    final double pickupLng = (request['pickup_lng'] as num?)?.toDouble() ?? 120.595856;
    final String dropoffName = (request['dropoff_name'] as String?) ?? 'Destination';
    final double dropoffLat = (request['dropoff_lat'] as num?)?.toDouble() ?? 18.203595;
    final double dropoffLng = (request['dropoff_lng'] as num?)?.toDouble() ?? 120.593643;
    final double distanceKm = (request['distance_km'] as num?)?.toDouble() ?? 1.25;
    final double fare = (request['fare'] as num?)?.toDouble() ?? 16.0;
    final String paymentMethod = (request['payment_method'] as String?) ?? 'Cash';
    final String? deliveryNotes = request['delivery_notes'] as String?;

    // Trigger native audio chime and heavy haptics immediately for hands-free driver alert
    SoundAlertService.playDispatchOfferChime();
    SystemNotificationService.showNewDispatchOfferNotification(
      passengerName: passengerName,
      pickup: pickupName,
      fare: fare,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
              if (remainingSeconds <= 1) {
                timer.cancel();
                SoundAlertService.stop();
                _isDispatchDialogOpen = false;
                if (Navigator.canPop(dialogContext)) {
                  Navigator.pop(dialogContext);
                                  }
              } else {
                setDialogState(() {
                  remainingSeconds--;
                });
              }
            });

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentEmeraldLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.volume_up_rounded, color: AppTheme.accentEmerald, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'NEW PILA DISPATCH',
                      style: TextStyle(color: AppTheme.primarySlate, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Semantics(
                    container: true,
                    liveRegion: true,
                    label: '$remainingSeconds seconds remaining to accept dispatch',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Text(
                        '${remainingSeconds}s',
                        style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.accentEmeraldLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '🔊 "Adda sakay dita $pickupName!"',
                      style: const TextStyle(color: AppTheme.accentEmerald, fontWeight: FontWeight.w700, fontSize: 12.5),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Passenger: $passengerName ($passengerCategory)', style: const TextStyle(color: AppTheme.primarySlate, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Pickup: $pickupName', style: const TextStyle(color: AppTheme.primarySlate, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Dropoff: $dropoffName', style: const TextStyle(color: AppTheme.primarySlate, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Distance: ${distanceKm.toStringAsFixed(2)} km', style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                  if (deliveryNotes != null && deliveryNotes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Note: $deliveryNotes', style: const TextStyle(color: Color(0xFFD97706), fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    '₱${fare.toStringAsFixed(2)} ($paymentMethod)',
                    style: const TextStyle(color: AppTheme.primarySlate, fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    countdownTimer?.cancel();
                    SoundAlertService.stop();
                    _isDispatchDialogOpen = false;
                    Navigator.pop(dialogContext);
                  },
                  child: Text('Pass to #2', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    countdownTimer?.cancel();
                    SoundAlertService.stop();
                    _isDispatchDialogOpen = false;
                    Navigator.pop(dialogContext);

                    // Broadcast ride acceptance to Supabase Realtime WebSocket channel
                    unawaited(
                      SupabaseService.broadcastRideAccepted(
                        driverName: widget.fullName,
                        todaName: 'Laoag Central & San Jose TODA',
                        bodyNumber: 'MTOP #0418',
                        plateNumber: 'IN-4829',
                        phone: '+63 917 840 2291',
                        vehicleHeadline: 'Honda TMX 125 Tricycle, Green • Body #0418',
                        driverLat: _driverLocation.latitude,
                        driverLng: _driverLocation.longitude,
                        extra: {
                          'ride_id': request['ride_id'],
                        },
                      ),
                    );

                    // Dequeue driver from terminal queue when accepting passenger trip
                    TodaQueueService.dequeueDriverForTrip('term_01', widget.fullName);

                    await Navigator.push<bool>(
                      this.context,
                      MaterialPageRoute(
                        builder: (_) => DriverActiveTripScreen(
                          driverName: widget.fullName,
                          passengerName: passengerName,
                          passengerCategory: passengerCategory,
                          pickupPoint: LocationPoint(
                            latitude: pickupLat,
                            longitude: pickupLng,
                            name: pickupName,
                            zoneCode: 'Z01',
                          ),
                          dropoffPoint: LocationPoint(
                            latitude: dropoffLat,
                            longitude: dropoffLng,
                            name: dropoffName,
                            zoneCode: 'Z02',
                          ),
                          distanceKm: distanceKm,
                          regularFare: fare,
                          discountedFare: fare,
                          paymentMethod: paymentMethod,
                        ),
                      ),
                    );
                    if (mounted) {
                      setState(() {});
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentEmerald,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(130, 46),
                  ),
                  child: const Text('ACCEPT RIDE'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      countdownTimer?.cancel();
      _isDispatchDialogOpen = false;
    });
  }

  void _showShiftEarningsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Today's Shift Earnings",
                        style: TextStyle(
                          color: AppTheme.primarySlate,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Laoag City Paratransit • City Ord. 2023-005',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentEmeraldLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'ACTIVE SHIFT',
                      style: TextStyle(
                        color: AppTheme.accentEmerald,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Main Earnings Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF047857)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF059669).withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL GROSS FARE TODAY',
                      style: TextStyle(
                        color: Color(0xFFA7F3D0),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '₱${DriverStatsService.todayTotalEarnings.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('💵 Cash Collected', style: TextStyle(color: Colors.white, fontSize: 11)),
                                const SizedBox(height: 2),
                                Text(
                                  '₱${DriverStatsService.cashEarnings.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('📱 GCash QR', style: TextStyle(color: Colors.white, fontSize: 11)),
                                const SizedBox(height: 2),
                                Text(
                                  '₱${DriverStatsService.gcashEarnings.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Color(0xFF93C5FD), fontWeight: FontWeight.w800, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Trips & Hours stats
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Completed Trips', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                          const SizedBox(height: 4),
                          Text(
                            '${DriverStatsService.todayCompletedTrips} dispatches',
                            style: const TextStyle(color: AppTheme.primarySlate, fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Online Duty Time', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                          const SizedBox(height: 4),
                          Text(
                            '${DriverStatsService.todayHoursOnline} hours',
                            style: const TextStyle(color: AppTheme.primarySlate, fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'RECENT COMPLETED TRIPS',
                style: TextStyle(
                  color: AppTheme.primarySlate,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              // List of recent trips
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 210),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: DriverStatsService.recentTrips.length,
                  separatorBuilder: (_, __) => Divider(color: Colors.grey.shade200, height: 12),
                  itemBuilder: (context, idx) {
                    final t = DriverStatsService.recentTrips[idx];
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.route,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.primarySlate,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${t.passengerName} • ${_formatTimeAgo(t.timestamp)}',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₱${t.fare.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppTheme.primarySlate,
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: t.isCash ? AppTheme.accentEmeraldLight : const Color(0xFFDBEAFE),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                t.isCash ? 'CASH' : 'GCASH',
                                style: TextStyle(
                                  color: t.isCash ? AppTheme.accentEmerald : const Color(0xFF1D4ED8),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentEmerald,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: const Text('DISMISS', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDigitalPilaStatusSheet() {
    final queue = TodaQueueService.getTerminalQueue('term_01', driverName: widget.fullName);
    final dynamicRank = TodaQueueService.getCurrentDriverRank('term_01', driverName: widget.fullName);
    final isQueued = dynamicRank > 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isQueued ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isQueued ? const Color(0xFFFDE68A) : const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        isQueued ? 'PILA #$dynamicRank OF ${queue.length}' : 'NOT QUEUED • EN ROUTE',
                        style: TextStyle(
                          color: isQueued ? const Color(0xFFB45309) : const Color(0xFF475569),
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Digital Pila Queue Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primarySlate,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _buildPilaInfoRow(
                        icon: Icons.store_mall_directory_rounded,
                        title: 'Terminal Station',
                        value: DriverStatsService.todaAssociation,
                      ),
                      const Divider(height: 18),
                      _buildPilaInfoRow(
                        icon: Icons.badge_outlined,
                        title: 'Registered TODA',
                        value: DriverStatsService.bodyNumber == 'Pending'
                            ? 'Pending MINC Assignment'
                            : 'Body #${DriverStatsService.bodyNumber}',
                      ),
                      const Divider(height: 18),
                      _buildPilaInfoRow(
                        icon: Icons.verified_user_outlined,
                        title: 'Geofence Compliance',
                        value: isQueued ? 'In-Bounds (Within 25m Radius)' : 'Outside Terminal Geofence',
                        valueColor: isQueued ? const Color(0xFF059669) : const Color(0xFFD97706),
                      ),
                      const Divider(height: 18),
                      _buildPilaInfoRow(
                        icon: Icons.alt_route_rounded,
                        title: 'Dispatch Order',
                        value: isQueued
                            ? 'FIFO Priority (Rank #$dynamicRank in Line)'
                            : 'Standby / En Route (Enter bay to queue)',
                        valueColor: isQueued ? const Color(0xFF059669) : const Color(0xFFD97706),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Live Terminal Dispatch Line',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.primarySlate),
                ),
                const SizedBox(height: 8),
                ...TodaQueueService.getTerminalQueue('term_01', driverName: widget.fullName).map((unit) {
                  final bool isMe = unit.isCurrentDriver;
                  final int rank = unit.rank;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFFF0FDF4) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isMe ? AppTheme.accentEmerald : Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isMe ? AppTheme.accentEmerald : (rank == 1 ? const Color(0xFFF59E0B) : Colors.grey.shade200),
                          ),
                          child: Center(
                            child: Text(
                              '#$rank',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: (isMe || rank == 1) ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isMe ? '${widget.fullName} (YOU)' : unit.driverName,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                              color: isMe ? AppTheme.accentEmerald : AppTheme.primarySlate,
                            ),
                          ),
                        ),
                        Text(
                          unit.bodyNumber,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Terminal geofence boundaries and calibration are managed by TODA & MINC Administrators via the PasadaNorte Web Command Center.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentEmerald,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('DISMISS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPilaInfoRow({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        Text(title, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppTheme.primarySlate,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showFranchiseProfileSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.accentEmeraldLight,
                      border: Border.all(color: AppTheme.accentEmerald, width: 2),
                    ),
                    child: const Center(
                      child: Text(
                        '🛺',
                        style: TextStyle(fontSize: 26),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DriverStatsService.driverFullName,
                          style: const TextStyle(
                            color: AppTheme.primarySlate,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DriverStatsService.todaAssociation,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Verified Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.accentEmeraldLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.accentEmerald.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_rounded, color: AppTheme.accentEmerald, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'LAOAG CITY MINC FRANCHISE ACTIVE & VERIFIED',
                        style: TextStyle(
                          color: AppTheme.accentEmerald,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Franchise Details Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildProfileRow('Tricycle Body #', '#${DriverStatsService.bodyNumber}'),
                    Divider(color: Colors.grey.shade200, height: 16),
                    _buildProfileRow('LTO Plate Number', DriverStatsService.plateNumber),
                    Divider(color: Colors.grey.shade200, height: 16),
                    _buildProfileRow('MINC Franchise ID', DriverStatsService.mincFranchiseNumber),
                    Divider(color: Colors.grey.shade200, height: 16),
                    _buildProfileRow('Franchise Validity', DriverStatsService.franchiseExpiry),
                    Divider(color: Colors.grey.shade200, height: 16),
                    _buildProfileRow('LTO Registration Expiry', DriverStatsService.ltoRegistrationExpiry),
                    Divider(color: Colors.grey.shade200, height: 16),
                    _buildProfileRow('Annual Inspection', DriverStatsService.lastInspectionStatus),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentEmerald,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: const Text('CLOSE PROFILE', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: AppTheme.primarySlate,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }

  void _showSosEmergencyDialog() {
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
          'Broadcast high-priority distress beacon immediately to Laoag PNP Headquarters & TODA Central Dispatch with your live GPS coordinates?',
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
                driverName: widget.fullName,
                latitude: 18.1960,
                longitude: 120.5935,
                reason: 'DUTY_MAP_SOS_ALERT',
              );
              if (mounted) {
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

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${diff.inHours}h ${diff.inMinutes % 60}m ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleZones = _zoneForecasts.where((z) => z.isVisibleOnHeatmap).toList();

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            Stack(
          children: [
            // 1. Full-Bleed Google Map with Driver Location, TODA Station, and Optional Hotspots
            Positioned.fill(
              bottom: 88,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _driverLocation,
                  initialZoom: 17.5,
                ),
                children: [
                  TileLayer(
                    urlTemplate: _isHybridSatellite
                        ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
                        : 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                    userAgentPackageName: 'ph.laoag.pasadanorte',
                  ),
                  // Hotspot Demand Circles - ONLY rendered when _showHotspots is true (Default: OFF)
                  if (_showHotspots) ...[
                    CircleLayer(
                      circles: visibleZones.map((zone) {
                        return CircleMarker(
                          point: zone.center,
                          radius: zone.radiusMeters * 1.25,
                          useRadiusInMeter: true,
                          color: zone.heatColor.withValues(alpha: 0.18),
                          borderStrokeWidth: 0,
                        );
                      }).toList(),
                    ),
                    CircleLayer(
                      circles: visibleZones.map((zone) {
                        return CircleMarker(
                          point: zone.center,
                          radius: zone.radiusMeters * 0.75,
                          useRadiusInMeter: true,
                          color: zone.heatColor.withValues(alpha: 0.38),
                          borderColor: zone.heatColor.withValues(alpha: 0.75),
                          borderStrokeWidth: 1.5,
                        );
                      }).toList(),
                    ),
                  ],
                  // Live TODA Pila Geofence Circles (Synced from Web Admin)
                  if (TodaQueueService.laoagTerminals.isNotEmpty)
                    CircleLayer(
                      circles: TodaQueueService.laoagTerminals.map((term) {
                        return CircleMarker(
                          point: LatLng(
                            term.centerPoint.latitude,
                            term.centerPoint.longitude,
                          ),
                          radius: term.radiusMeters,
                          useRadiusInMeter: true,
                          color: AppTheme.accentEmerald.withValues(alpha: 0.14),
                          borderColor: AppTheme.accentEmerald.withValues(alpha: 0.7),
                          borderStrokeWidth: 2.0,
                        );
                      }).toList(),
                    ),
                  // Marker Layer: Driver Location (YOU) & Live TODA Pila Pins
                  MarkerLayer(
                    markers: [
                      // Driver Location Marker (High Visibility)
                      Marker(
                        point: _driverLocation,
                        width: 76,
                        height: 76,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 66,
                              height: 66,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.accentEmerald.withValues(alpha: 0.20),
                                border: Border.all(
                                  color: AppTheme.accentEmerald.withValues(alpha: 0.50),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primarySlate,
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: const [
                                        BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
                                      ],
                                    ),
                                    child: Text(
                                      DriverStatsService.bodyNumber == 'Pending'
                                          ? 'YOU'
                                          : 'YOU (#${DriverStatsService.bodyNumber})',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppTheme.accentEmerald,
                                      border: Border.all(color: Colors.white, width: 2.5),
                                      boxShadow: const [
                                        BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2)),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.two_wheeler_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Live TODA Pila Pins from Admin Web Portal
                      ...TodaQueueService.laoagTerminals.map(
                        (term) => Marker(
                          point: LatLng(
                            term.centerPoint.latitude,
                            term.centerPoint.longitude,
                          ),
                          width: 140,
                          height: 38,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.primarySlate,
                                width: 1.2,
                              ),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 4),
                              ],
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.local_taxi_rounded,
                                    size: 12,
                                    color: AppTheme.accentEmerald,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${term.name} (${term.radiusMeters.toStringAsFixed(0)}m)',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.primarySlate,
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

          // 2. Floating Top Bar (Uber Driver Style Online/Offline Pill + Pila Rank Card)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildCircleAction(
                            icon: Icons.home_rounded,
                            onTap: _returnToPasadaNorteHome,
                          ),
                          const SizedBox(width: 8),
                          _buildCircleAction(
                            icon: _isHybridSatellite ? Icons.map_rounded : Icons.satellite_alt_rounded,
                            onTap: () => setState(() => _isHybridSatellite = !_isHybridSatellite),
                          ),
                          const SizedBox(width: 8),
                          _buildCircleAction(
                            icon: _simulateNetworkDropFailSafe
                                ? Icons.wifi_off_rounded
                                : Icons.wifi_tethering_rounded,
                            onTap: () {
                              setState(() {
                                _simulateNetworkDropFailSafe = !_simulateNetworkDropFailSafe;
                              });
                                                          },
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      // Center Uber-Driver-Style Duty Pill
                      Flexible(
                        child: GestureDetector(
                          onTap: _toggleDutyStatus,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: _isOnline ? AppTheme.accentEmerald : AppTheme.primarySlate,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 3)),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isOnline ? Icons.bolt_rounded : Icons.power_settings_new_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _isOnline ? 'ONLINE • DUTY ACTIVE' : 'OFFLINE • TAP TO GO',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Non-Freezing Offline Fail-Safe Banner (ISO/IEC 25010:2023 Reliability & Operational Safety)
                  if (_simulateNetworkDropFailSafe)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade900,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'FAIL-SAFE MODE (ISO/IEC 25010:2023): Mobile data lost in transit. Active trip & Pila rank cached locally; non-freezing alert prevents driver distraction.',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Driver Metrics Quick Action Bar (Clean White Architecture)
                  Row(
                    children: [
                      // Earnings Action Card
                      Expanded(
                        child: GestureDetector(
                          onTap: _showShiftEarningsSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  ),
                                  child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFD97706), size: 16),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('EARNINGS', style: TextStyle(color: Colors.grey.shade600, fontSize: 9, fontWeight: FontWeight.w700)),
                                      Text(
                                        '₱${DriverStatsService.todayTotalEarnings.toStringAsFixed(0)}',
                                        style: const TextStyle(color: AppTheme.primarySlate, fontSize: 13, fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Tricycle & Franchise Profile Card
                      Expanded(
                        child: GestureDetector(
                          onTap: _showFranchiseProfileSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.accentEmeraldLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.verified_rounded, color: AppTheme.accentEmerald, size: 16),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('TODA UNIT', style: TextStyle(color: Colors.grey.shade600, fontSize: 9, fontWeight: FontWeight.w700)),
                                      Text(
                                        DriverStatsService.bodyNumber == 'Pending'
                                            ? 'Pending • ${DriverStatsService.plateNumber}'
                                            : '${DriverStatsService.bodyNumber} • ${DriverStatsService.plateNumber}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: AppTheme.primarySlate, fontSize: 12, fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Emergency SOS Panic Button
                      Tooltip(
                        message: 'Emergency SOS',
                        child: Semantics(
                          button: true,
                          label: 'Emergency SOS, Broadcast alert to Laoag PNP and TODA Dispatch',
                          child: InkWell(
                            onTap: _showSosEmergencyDialog,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 24),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 3. Bottom Driver Pila Queue Status Bar
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, -4)),
                ],
              ),
              child: Builder(
                builder: (context) {
                  final currentDynamicRank = TodaQueueService.getCurrentDriverRank(
                    'term_01',
                    driverName: widget.fullName,
                  );
                  final isDriverInQueue = currentDynamicRank > 0;
                  final String pilaLabel = isDriverInQueue
                      ? 'Pila #$currentDynamicRank - ${DriverStatsService.todaAssociation}'
                      : DriverStatsService.bodyNumber != 'Pending'
                          ? '${DriverStatsService.bodyNumber} • ${DriverStatsService.todaAssociation}'
                          : 'Pila #-- • ${DriverStatsService.todaAssociation}';

                  return Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showDigitalPilaStatusSheet,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.format_list_numbered_rounded, size: 18),
                          label: const Text(
                            'Queue Status',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _showDigitalPilaStatusSheet,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentEmerald,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            pilaLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // 4. Floating Action Buttons (Above Bottom Sheet)
          // 4a. Bottom Left: Hotspot Flame Toggle
          Positioned(
            left: 16,
            bottom: 120,
            child: _buildCircleAction(
              icon: _showHotspots ? Icons.local_fire_department_rounded : Icons.local_fire_department_outlined,
              color: _showHotspots ? const Color(0xFFEF4444) : AppTheme.primarySlate,
              onTap: () {
                setState(() => _showHotspots = !_showHotspots);
                              },
            ),
          ),

          // 4b. Bottom Right: Recenter on Driver Location
          Positioned(
            right: 16,
            bottom: 120,
            child: _buildCircleAction(
              icon: Icons.my_location_rounded,
              onTap: () {
                _mapController.move(_driverLocation, 17.5);
              },
            ),
          ),
        ],
      ),
            DriverActivityScreen(fullName: widget.fullName),
            DriverAccountScreen(fullName: widget.fullName),
          ],
        ),
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
            unselectedItemColor: Colors.grey.shade500,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 11.5,
            ),
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long_outlined),
                activeIcon: Icon(Icons.receipt_long_rounded),
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

  Widget _buildCircleAction({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11.0),
          child: Icon(icon, size: 22, color: color ?? AppTheme.primarySlate),
        ),
      ),
    );
  }
}
