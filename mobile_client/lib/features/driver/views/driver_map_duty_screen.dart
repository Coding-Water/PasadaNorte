import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/demand_forecast_service.dart';
import '../../../core/services/toda_queue_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/views/welcome_onboarding_screen.dart';
import '../../admin/views/web_admin_portal_screen.dart';
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
  final int _queuePosition = 1;
  int _selectedHour = 12;
  bool _isWeekday = true;
  bool _isHybridSatellite = false; // Google Roadmap vs Google Hybrid Satellite
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
    final forecasts = await DemandForecastService.getHourlyForecast(
      hourOfDay: _selectedHour,
      isWeekday: _isWeekday,
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
              if (remainingSeconds <= 1) {
                timer.cancel();
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
              backgroundColor: AppTheme.primarySlate,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentEmerald,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'NEW PILA DISPATCH',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${remainingSeconds}s',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ),
                ],
              ),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🔊 "Adda sakay dita Laoag Central Market!"',
                    style: TextStyle(color: Color(0xFF4ADE80), fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  SizedBox(height: 14),
                  Text('Pickup: Laoag Central Terminal & Market', style: TextStyle(color: Colors.white, fontSize: 13)),
                  SizedBox(height: 4),
                  Text('Dropoff: MMSU Laoag Campus', style: TextStyle(color: Colors.white, fontSize: 13)),
                  SizedBox(height: 4),
                  Text('Distance: 1.50 km • Regular Fare', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                  SizedBox(height: 12),
                  Text(
                    '₱21.00 (Cash)',
                    style: TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    countdownTimer?.cancel();
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Pass to #2', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  onPressed: () {
                    countdownTimer?.cancel();
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Ride Accepted! Navigating to pickup.'),
                        backgroundColor: AppTheme.accentEmerald,
                      ),
                    );
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

  String _formatHour(int h) {
    if (h == 0) return '12:00 AM';
    if (h < 12) return '$h:00 AM';
    if (h == 12) return '12:00 PM';
    return '${h - 12}:00 PM';
  }

  @override
  Widget build(BuildContext context) {
    final visibleZones = _zoneForecasts.where((z) => z.isVisibleOnHeatmap).toList();
    final suppressedCount = _zoneForecasts.length - visibleZones.length;

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
            // 1. Full-Bleed Google Map with Thermal Demand Radar & TODA Geofence Rings
            Positioned.fill(
              bottom: 215,
              child: FlutterMap(
                options: const MapOptions(
                  initialCenter: LatLng(18.1960, 120.5935),
                  initialZoom: 14.5,
                ),
                children: [
                  TileLayer(
                    urlTemplate: _isHybridSatellite
                        ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
                        : 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                    userAgentPackageName: 'ph.laoag.pasadanorte',
                  ),
                CircleLayer(
                  circles: visibleZones.map((zone) {
                    return CircleMarker(
                      point: zone.center,
                      radius: zone.radiusMeters * 1.25,
                      useRadiusInMeter: true,
                      color: zone.heatColor.withOpacity(0.18),
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
                      color: zone.heatColor.withOpacity(0.38),
                      borderColor: zone.heatColor.withOpacity(0.75),
                      borderStrokeWidth: 1.5,
                    );
                  }).toList(),
                ),
                CircleLayer(
                  circles: TodaQueueService.laoagTerminals.map((term) {
                    return CircleMarker(
                      point: term.centerPoint.latLng,
                      radius: term.radiusMeters,
                      useRadiusInMeter: true,
                      color: AppTheme.primarySlate.withOpacity(0.22),
                      borderColor: AppTheme.primarySlate,
                      borderStrokeWidth: 2,
                    );
                  }).toList(),
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
                      // Center Uber-Driver-Style Duty Pill
                      GestureDetector(
                        onTap: _toggleDutyStatus,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: _isOnline ? AppTheme.accentEmerald : AppTheme.primarySlate,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
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
                              Text(
                                _isOnline ? 'ONLINE • DUTY ACTIVE' : 'OFFLINE • TAP TO GO',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _buildCircleAction(
                        icon: Icons.admin_panel_settings_rounded,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const WebAdminPortalScreen()),
                          );
                          setState(() {});
                        },
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

                  // Floating Digital Pila Rank Pill (Tap to calibrate)
                  if (_isOnline)
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TodaQueueScreen(driverName: widget.fullName),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.primarySlate.withOpacity(0.94),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'PILA #$_queuePosition',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Laoag Central Terminal TODA',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  Text(
                                    'Tap to open Digital Pila GPS Calibration',
                                    style: TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.tune_rounded, color: Colors.amber, size: 20),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 3. Bottom Driver Radar & Dispatch Sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4)),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ML Demand Radar (${_formatHour(_selectedHour)})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppTheme.primarySlate,
                            ),
                          ),
                          Text(
                            '${visibleZones.length}/${_zoneForecasts.length} Laoag zones shaded (>=5 req) • $suppressedCount hidden (k=5 PIA rule)',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      ChoiceChip(
                        label: Text(
                          _isWeekday ? 'Weekday' : 'Weekend',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: _isWeekday ? Colors.white : AppTheme.primarySlate,
                          ),
                        ),
                        selected: _isWeekday,
                        selectedColor: AppTheme.primarySlate,
                        onSelected: (v) {
                          _isWeekday = !_isWeekday;
                          _loadForecast();
                        },
                      ),
                    ],
                  ),
                  Slider(
                    value: _selectedHour.toDouble(),
                    min: 5,
                    max: 22,
                    divisions: 17,
                    activeColor: AppTheme.accentEmerald,
                    label: _formatHour(_selectedHour),
                    onChanged: (val) {
                      setState(() => _selectedHour = val.round());
                      _loadForecast();
                    },
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TodaQueueScreen(driverName: widget.fullName),
                              ),
                            );
                          },
                          icon: const Icon(Icons.sensors_rounded, size: 18),
                          label: const Text('Digital Pila', style: TextStyle(fontSize: 13)),
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
          // 4. Edge Swipe Detector (Swipe Left or Right at Screen Edges -> PasadaNorte Home)
          Positioned(
            left: 0,
            top: 80,
            bottom: 225,
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
            bottom: 225,
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
