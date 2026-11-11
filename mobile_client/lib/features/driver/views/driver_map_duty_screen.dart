import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/demand_forecast_service.dart';
import '../../../core/services/driver_stats_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/sound_alert_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/toda_queue_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/views/welcome_onboarding_screen.dart';
import 'driver_active_trip_screen.dart';
import 'toda_queue_screen.dart';

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
  bool _isOnline = true;
  bool _simulateNetworkDropFailSafe = false; // ISO/IEC 25010:2023 operational fail-safe during mobile data loss
  int _queuePosition = 1;
  bool _showHotspots = false; // Default OFF so driver map is clean and does not cause dizziness
  bool _isHybridSatellite = false; // Google Roadmap vs Google Hybrid Satellite
  final LatLng _driverLocation = const LatLng(18.1960, 120.5935); // Laoag Central Terminal / Aurora Park
  final MapController _mapController = MapController();
  List<DemandZoneForecast> _zoneForecasts = [];

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
    _loadForecast();
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isOnline
              ? 'You are ONLINE. Passive GPS Digital Pila & Heatmap active.'
              : 'You are OFFLINE.',
        ),
        backgroundColor: _isOnline ? AppTheme.accentEmerald : AppTheme.primarySlate,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _simulateIncomingRideRequest() {
    int remainingSeconds = TodaQueueService.autoPassSeconds; // 15 seconds
    Timer? countdownTimer;

    // Trigger native audio chime and heavy haptics immediately for hands-free driver alert
    SoundAlertService.playDispatchOfferChime();

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
                if (Navigator.canPop(dialogContext)) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('15s elapsed. Booking passed to Rank #2 driver.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
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
                    child: const Text(
                      '🔊 "Adda sakay dita Laoag Central Market!"',
                      style: TextStyle(color: AppTheme.accentEmerald, fontWeight: FontWeight.w700, fontSize: 12.5),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Pickup: Laoag Central Terminal & Public Market', style: TextStyle(color: AppTheme.primarySlate, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text('Dropoff: MMSU Laoag Campus (CTE / CIT Gate)', style: TextStyle(color: AppTheme.primarySlate, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Distance: 1.25 km • Student 20% Discount', style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                  const SizedBox(height: 12),
                  const Text(
                    '₱16.00 (Cash)',
                    style: TextStyle(color: AppTheme.primarySlate, fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    countdownTimer?.cancel();
                    SoundAlertService.stop();
                    Navigator.pop(dialogContext);
                  },
                  child: Text('Pass to #2', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    countdownTimer?.cancel();
                    SoundAlertService.stop();
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
                        driverLat: 18.192096,
                        driverLng: 120.594356,
                      ),
                    );

                    // Dequeue driver from terminal queue when accepting passenger trip
                    TodaQueueService.dequeueDriverForTrip('term_01', widget.fullName);

                    final queuedInPila = await Navigator.push<bool>(
                      this.context,
                      MaterialPageRoute(
                        builder: (_) => DriverActiveTripScreen(
                          driverName: widget.fullName,
                          pickupPoint: const LocationPoint(
                            latitude: 18.194096,
                            longitude: 120.595856,
                            name: 'Laoag Central Terminal & Public Market',
                            zoneCode: 'Z01',
                          ),
                          dropoffPoint: const LocationPoint(
                            latitude: 18.203595,
                            longitude: 120.593643,
                            name: 'MMSU Laoag Campus (CTE / CIT Gate)',
                            zoneCode: 'Z02',
                          ),
                          distanceKm: 1.25,
                          regularFare: 20.00,
                          discountedFare: 16.00,
                          passengerCategory: 'STUDENT (20% STATUTORY DISCOUNT)',
                        ),
                      ),
                    );
                    if (mounted) {
                      if (queuedInPila == true) {
                        final currentRank = TodaQueueService.getCurrentDriverRank('term_01', driverName: widget.fullName);
                        setState(() {
                          _queuePosition = currentRank > 0 ? currentRank : 5;
                        });
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '✓ Returned to Terminal & Queued (Rank #$_queuePosition in Line)!',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: AppTheme.accentEmerald,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 4),
                            action: SnackBarAction(
                              label: 'VIEW STATUS',
                              textColor: Colors.white,
                              onPressed: _showDigitalPilaStatusSheet,
                            ),
                          ),
                        );
                      }
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
    ).then((_) => countdownTimer?.cancel());
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
                        value: 'Laoag Central Terminal TODA',
                      ),
                      const Divider(height: 18),
                      _buildPilaInfoRow(
                        icon: Icons.badge_outlined,
                        title: 'Registered TODA',
                        value: 'CENTRAL-TODA',
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TodaQueueScreen(
                                driverName: widget.fullName,
                                initialTerminalId: 'term_01',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.fullscreen_rounded, size: 18),
                        label: const Text('FULL BOARD', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentEmerald,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('DISMISS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                      ),
                    ),
                  ],
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
                        const Text(
                          DriverStatsService.driverFullName,
                          style: TextStyle(
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

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${diff.inHours}h ${diff.inMinutes % 60}m ago';
    }
  }

  String _formatHour(int h) {
    if (h == 0) return '12:00 AM';
    if (h < 12) return '$h:00 AM';
    if (h == 12) return '12:00 PM';
    return '${h - 12}:00 PM';
  }

  @override
  Widget build(BuildContext context) {
    final visibleZones = _zoneForecasts.where((z) => z.isVisibleOnHeatmap).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _returnToPasadaNorteHome();
        }
      },
      child: Scaffold(
        body: Stack(
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
                  // Marker Layer: Driver Location (YOU) & Terminal Station Pins
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
                            Column(
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
                                  child: const Text(
                                    'YOU (#0042)',
                                    style: TextStyle(
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
                          ],
                        ),
                      ),
                      // TODA Station Landmark Marker
                      Marker(
                        point: const LatLng(18.1972, 120.5925),
                        width: 100,
                        height: 32,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.primarySlate, width: 1.2),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 4),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.local_taxi_rounded, size: 12, color: AppTheme.accentEmerald),
                              SizedBox(width: 3),
                              Text(
                                'TODA PILA',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primarySlate,
                                ),
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _simulateNetworkDropFailSafe
                                        ? 'Fail-Safe Active (ISO/IEC 25010:2023): Sudden mobile data loss simulated. Queue & route cached locally without freezing UI.'
                                        : 'Network Restored: Graceful offline-to-online state recovery complete.',
                                  ),
                                  backgroundColor: _simulateNetworkDropFailSafe
                                      ? Colors.amber.shade900
                                      : AppTheme.accentEmerald,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
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

                  // Floating Digital Pila Rank Pill (Read-only live status)
                  if (_isOnline)
                    GestureDetector(
                      onTap: _showDigitalPilaStatusSheet,
                      child: Builder(
                        builder: (context) {
                          final currentDynamicRank = TodaQueueService.getCurrentDriverRank('term_01', driverName: widget.fullName);
                          final isDriverInQueue = currentDynamicRank > 0;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: LocationService.hasMockLocationViolation
                                    ? Colors.red.shade400
                                    : Colors.grey.shade200,
                                width: LocationService.hasMockLocationViolation ? 1.5 : 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: LocationService.hasMockLocationViolation
                                      ? Colors.red.withValues(alpha: 0.15)
                                      : Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: LocationService.hasMockLocationViolation
                                        ? const Color(0xFFFEE2E2)
                                        : (isDriverInQueue ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9)),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: LocationService.hasMockLocationViolation
                                          ? const Color(0xFFFCA5A5)
                                          : (isDriverInQueue ? const Color(0xFFFDE68A) : const Color(0xFFCBD5E1)),
                                    ),
                                  ),
                                  child: Text(
                                    LocationService.hasMockLocationViolation
                                        ? 'SPOOF BLOCKED'
                                        : (isDriverInQueue ? 'PILA #$currentDynamicRank' : 'EN ROUTE'),
                                    style: TextStyle(
                                      color: LocationService.hasMockLocationViolation
                                          ? const Color(0xFF991B1B)
                                          : (isDriverInQueue ? const Color(0xFFB45309) : const Color(0xFF475569)),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        LocationService.hasMockLocationViolation
                                            ? 'Mock GPS Violation Detected'
                                            : 'Laoag Central Terminal TODA',
                                        style: TextStyle(
                                          color: LocationService.hasMockLocationViolation
                                              ? Colors.red.shade900
                                              : AppTheme.primarySlate,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                      Text(
                                        LocationService.hasMockLocationViolation
                                            ? 'Queue paused under Ord. 2023-005. Tap to inspect.'
                                            : (isDriverInQueue
                                                ? 'Rank #$currentDynamicRank in Digital Pila • Standing by for dispatch'
                                                : 'Outside terminal bay • Enter geofence to queue at tail'),
                                        style: TextStyle(
                                          color: LocationService.hasMockLocationViolation
                                              ? Colors.red.shade700
                                              : (isDriverInQueue ? const Color(0xFF059669) : const Color(0xFFD97706)),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  LocationService.hasMockLocationViolation
                                      ? Icons.gpp_bad_rounded
                                      : (isDriverInQueue ? Icons.check_circle_rounded : Icons.alt_route_rounded),
                                  color: LocationService.hasMockLocationViolation
                                      ? Colors.red.shade700
                                      : (isDriverInQueue ? const Color(0xFF059669) : const Color(0xFFD97706)),
                                  size: 20,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Joyride Driver Metrics Quick Action Bar (Passenger Clean White Architecture)
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
                                      const Text(
                                        '#${DriverStatsService.bodyNumber} • ${DriverStatsService.plateNumber}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: AppTheme.primarySlate, fontSize: 12, fontWeight: FontWeight.w800),
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

          // 3. Bottom Driver Dispatch Sheet (Simplified, Compact)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, -4)),
                ],
              ),
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
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showDigitalPilaStatusSheet,
                          icon: const Icon(Icons.format_list_numbered_rounded, size: 18),
                          label: const Text('Queue Status', style: TextStyle(fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _simulateIncomingRideRequest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentEmerald,
                          ),
                          icon: const Icon(Icons.notifications_active_rounded, size: 18),
                          label: const Text('Test 15s Ride Dispatch', style: TextStyle(fontSize: 13.5)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 4. Floating Action Buttons (Above Bottom Sheet)
          // 4a. Bottom Left: Hotspot Flame Toggle
          Positioned(
            left: 16,
            bottom: 112,
            child: _buildCircleAction(
              icon: _showHotspots ? Icons.local_fire_department_rounded : Icons.local_fire_department_outlined,
              color: _showHotspots ? const Color(0xFFEF4444) : AppTheme.primarySlate,
              onTap: () {
                setState(() => _showHotspots = !_showHotspots);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _showHotspots
                          ? 'Demand hotspots visible for ${_formatHour(DateTime.now().hour)} (${DateTime.now().weekday <= 5 ? "Weekday" : "Weekend"}).'
                          : 'Demand hotspots hidden. Map clean & focused on your location.',
                    ),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ),

          // 4b. Bottom Right: Recenter on Driver Location
          Positioned(
            right: 16,
            bottom: 112,
            child: _buildCircleAction(
              icon: Icons.my_location_rounded,
              onTap: () {
                _mapController.move(_driverLocation, 17.5);
              },
            ),
          ),

          // 5. Edge Swipe Detector (Swipe Left or Right at Screen Edges -> PasadaNorte Home)
          Positioned(
            left: 0,
            top: 80,
            bottom: 115,
            width: 26,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0).abs() > 250) {
                  _returnToPasadaNorteHome();
                }
              },
            ),
          ),
          Positioned(
            right: 0,
            top: 80,
            bottom: 115,
            width: 26,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0).abs() > 250) {
                  _returnToPasadaNorteHome();
                }
              },
            ),
          ),
        ],
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
