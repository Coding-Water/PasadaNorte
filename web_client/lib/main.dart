import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String kSupabaseUrl = 'https://zrkkbknndavvprejskjy.supabase.co';
const String kSupabasePublishableKey =
    'sb_publishable_kMbiVj_on1b8XUdkTKvHmw_urG_F5sz';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // ignore: deprecated_member_use
    await Supabase.initialize(
      url: kSupabaseUrl,
      // ignore: deprecated_member_use
      anonKey: kSupabasePublishableKey,
    );
  } catch (_) {}
  runApp(const PasadaNorteWebAdminApp());
}

class PasadaNorteWebAdminApp extends StatelessWidget {
  const PasadaNorteWebAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PasadaNorte — Laoag City TODA & MINC Web Command Center',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF059669),
          primary: const Color(0xFF059669),
          secondary: const Color(0xFFF59E0B),
          surface: Colors.white,
        ),
      ),
      home: const WebAdminDashboard(),
    );
  }
}

class WebAdminDashboard extends StatefulWidget {
  const WebAdminDashboard({super.key});

  @override
  State<WebAdminDashboard> createState() => _WebAdminDashboardState();
}

class _WebAdminDashboardState extends State<WebAdminDashboard> {
  // Navigation State
  String _selectedSection = 'Analytics';
  int _analyticsSubTab = 0;
  bool _isSyncing = false;
  String _selectedDateRange = 'Jun 2026';

  // Live Supabase Synced Fare State (City Ord. 2023-005)
  double _regFirstKm = 20.00;
  double _discFirstKm = 16.00;
  double _baseDistKm = 1.00;
  double _succKm = 5.00;

  // ML Demand Simulator State
  double _simulatedHour = 12.0;
  String _activeScenario = 'Normal';
  String _selectedZoneCode = 'Z01';

  // Search & Filter State
  String _dispatchSearchQuery = '';
  String _driverSearchQuery = '';
  String _dispatchFilter = 'All'; // 'All', 'Compliant', 'Overcharged'
  final String _driverTodaFilter = 'All';

  // Terminals State
  final List<Map<String, dynamic>> _terminals = [
    {
      'id': 'TERM-01',
      'name': 'Laoag Central Terminal & Public Market TODA',
      'code': 'TODA-01',
      'radius': 30.0,
      'joinSpeed': 5.0,
      'dwell': 45,
      'activeUnits': 42,
      'dispatches': 1420,
      'lat': 18.1972,
      'lng': 120.5925,
    },
    {
      'id': 'TERM-02',
      'name': 'MMSU Laoag Campus (CTE / CIT Gate) TODA',
      'code': 'TODA-02',
      'radius': 25.0,
      'joinSpeed': 5.0,
      'dwell': 30,
      'activeUnits': 28,
      'dispatches': 980,
      'lat': 18.1925,
      'lng': 120.5960,
    },
    {
      'id': 'TERM-03',
      'name': 'Robinsons Place Ilocos / San Nicolas Boundary TODA',
      'code': 'TODA-03',
      'radius': 35.0,
      'joinSpeed': 5.0,
      'dwell': 60,
      'activeUnits': 19,
      'dispatches': 510,
      'lat': 18.1845,
      'lng': 120.5912,
    },
    {
      'id': 'TERM-04',
      'name': 'Laoag City General Hospital (LCGH) TODA',
      'code': 'TODA-04',
      'radius': 20.0,
      'joinSpeed': 5.0,
      'dwell': 40,
      'activeUnits': 14,
      'dispatches': 340,
      'lat': 18.1880,
      'lng': 120.5890,
    },
    {
      'id': 'TERM-05',
      'name': 'Laoag International Airport (Gabu) TODA',
      'code': 'TODA-05',
      'radius': 30.0,
      'joinSpeed': 5.0,
      'dwell': 50,
      'activeUnits': 8,
      'dispatches': 85,
      'lat': 18.1811,
      'lng': 120.5306,
    },
  ];

  // 10 Laoag Zones (Spatial-Temporal Forecasting Calibration)
  final List<Map<String, dynamic>> _mlZones = [
    {
      'code': 'Z01',
      'name': 'Public Market & Commercial Complex',
      'trips': 1420,
      'baseForecast': 38.0,
      'color': const Color(0xFFEF4444),
      'x': 0.48,
      'y': 0.44,
      'lat': 18.1972,
      'lng': 120.5925,
    },
    {
      'code': 'Z02',
      'name': 'MMSU CIT / CTE P. Gomez Campus',
      'trips': 980,
      'baseForecast': 32.0,
      'color': const Color(0xFFF59E0B),
      'x': 0.58,
      'y': 0.52,
      'lat': 18.1925,
      'lng': 120.5960,
    },
    {
      'code': 'Z03',
      'name': 'Laoag Sinking Bell Tower & Plaza',
      'trips': 510,
      'baseForecast': 18.0,
      'color': const Color(0xFF10B981),
      'x': 0.51,
      'y': 0.40,
      'lat': 18.1965,
      'lng': 120.5938,
    },
    {
      'code': 'Z04',
      'name': 'Laoag City General Hospital (LCGH)',
      'trips': 340,
      'baseForecast': 12.0,
      'color': const Color(0xFF10B981),
      'x': 0.42,
      'y': 0.62,
      'lat': 18.1880,
      'lng': 120.5890,
    },
    {
      'code': 'Z05',
      'name': 'Gov. Roque B. Ablan Sr. Memorial Hospital',
      'trips': 290,
      'baseForecast': 10.0,
      'color': const Color(0xFF10B981),
      'x': 0.64,
      'y': 0.38,
      'lat': 18.1990,
      'lng': 120.5980,
    },
    {
      'code': 'Z06',
      'name': 'Provincial Capitol & Aurora Park',
      'trips': 365,
      'baseForecast': 14.0,
      'color': const Color(0xFF10B981),
      'x': 0.46,
      'y': 0.38,
      'lat': 18.1960,
      'lng': 120.5920,
    },
    {
      'code': 'Z07',
      'name': 'Northwestern University (NWU Corridor)',
      'trips': 310,
      'baseForecast': 11.0,
      'color': const Color(0xFF10B981),
      'x': 0.38,
      'y': 0.30,
      'lat': 18.2040,
      'lng': 120.5885,
    },
    {
      'code': 'Z08',
      'name': 'Robinsons Place / San Nicolas Boundary',
      'trips': 220,
      'baseForecast': 9.0,
      'color': const Color(0xFF6B7280),
      'x': 0.50,
      'y': 0.76,
      'lat': 18.1845,
      'lng': 120.5912,
    },
    {
      'code': 'Z09',
      'name': 'Partas Bus Terminal & Gilbert Bridge',
      'trips': 110,
      'baseForecast': 5.0,
      'color': const Color(0xFF6B7280),
      'x': 0.44,
      'y': 0.54,
      'lat': 18.1910,
      'lng': 120.5905,
    },
    {
      'code': 'Z10',
      'name': 'Laoag Airport Corridor (Gabu West)',
      'trips': 20,
      'baseForecast': 2.0,
      'color': const Color(0xFF9CA3AF),
      'x': 0.16,
      'y': 0.70,
      'lat': 18.1811,
      'lng': 120.5306,
    },
  ];

  // Dispatch Trips Audit Data (Anti-Overcharging Sentinel)
  final List<Map<String, dynamic>> _dispatchTrips = [
    {
      'id': 'TRP-9401',
      'rider': 'Maria Clara Santos',
      'riderRole': 'Student (20% Disc)',
      'driver': 'Eduardo Castro',
      'bodyNo': 'T-0142',
      'toda': 'Laoag Central TODA',
      'origin': 'Laoag Central Terminal',
      'destination': 'MMSU CTE P. Gomez St.',
      'distanceKm': 1.25,
      'expectedFare': 16.00,
      'collectedFare': 16.00,
      'status': 'COMPLIANT',
      'time': '10:42 AM',
      'payment': 'Cash Paid',
    },
    {
      'id': 'TRP-9402',
      'rider': 'Joshua Agcaoili',
      'riderRole': 'Regular',
      'driver': 'Nestor Valdez',
      'bodyNo': 'T-0855',
      'toda': 'Laoag Central TODA',
      'origin': 'Public Market J.P. Rizal',
      'destination': 'Gov. Roque Ablan Hospital',
      'distanceKm': 1.80,
      'expectedFare': 24.00,
      'collectedFare': 40.00,
      'status': 'OVERCHARGED',
      'overchargeAmount': 16.00,
      'time': '11:15 AM',
      'payment': 'Cash Paid',
    },
    {
      'id': 'TRP-9403',
      'rider': 'Elena Dumlao',
      'riderRole': 'Senior Citizen (20% Disc)',
      'driver': 'Rogelio Pascual',
      'bodyNo': 'T-0219',
      'toda': 'MMSU-San Nicolas TODA',
      'origin': 'MMSU CIT Gate 2',
      'destination': 'Robinsons Place Ilocos',
      'distanceKm': 2.40,
      'expectedFare': 23.00,
      'collectedFare': 23.00,
      'status': 'COMPLIANT',
      'time': '11:28 AM',
      'payment': 'GCash Digital',
    },
    {
      'id': 'TRP-9404',
      'rider': 'Bryan Fontanilla',
      'riderRole': 'Regular',
      'driver': 'Danilo Ramos',
      'bodyNo': 'T-0404',
      'toda': 'Airport-Nalbo TODA',
      'origin': 'Partas Bus Terminal',
      'destination': 'Laoag City General Hospital',
      'distanceKm': 1.60,
      'expectedFare': 23.00,
      'collectedFare': 35.00,
      'status': 'OVERCHARGED',
      'overchargeAmount': 12.00,
      'time': '11:50 AM',
      'payment': 'Cash Paid',
    },
    {
      'id': 'TRP-9405',
      'rider': 'Grace Malapit',
      'riderRole': 'Student (20% Disc)',
      'driver': 'Ferdinand Corpuz',
      'bodyNo': 'T-0331',
      'toda': 'Capitol TODA',
      'origin': 'Ilocos Norte Capitol',
      'destination': 'Northwestern University',
      'distanceKm': 2.10,
      'expectedFare': 21.50,
      'collectedFare': 21.50,
      'status': 'COMPLIANT',
      'time': '12:05 PM',
      'payment': 'Cash Paid',
    },
  ];

  // MINC Registered Drivers & Operators Directory
  final List<Map<String, dynamic>> _driverDirectory = [
    {
      'bodyNo': 'T-0142',
      'mtop': 'MTOP-LAO-2024-00142',
      'name': 'Eduardo "Manong Eddie" Castro',
      'toda': 'Laoag Central TODA',
      'phone': '+63 918 992 3310',
      'plateNo': '9042-NA',
      'status': 'Active Duty',
      'verification': 96.4,
      'trips': 142,
      'rating': 4.9,
    },
    {
      'bodyNo': 'T-0219',
      'mtop': 'MTOP-LAO-2023-00219',
      'name': 'Rogelio Pascual',
      'toda': 'MMSU-San Nicolas TODA',
      'phone': '+63 920 445 1198',
      'plateNo': '4412-NB',
      'status': 'In Pila (Rank #1)',
      'verification': 94.8,
      'trips': 98,
      'rating': 4.8,
    },
    {
      'bodyNo': 'T-0331',
      'mtop': 'MTOP-LAO-2024-00331',
      'name': 'Ferdinand Corpuz',
      'toda': 'Capitol TODA',
      'phone': '+63 917 551 2284',
      'plateNo': '8123-NA',
      'status': 'Active Duty',
      'verification': 95.1,
      'trips': 114,
      'rating': 4.9,
    },
    {
      'bodyNo': 'T-0404',
      'mtop': 'MTOP-LAO-2022-00404',
      'name': 'Danilo Ramos',
      'toda': 'Airport-Nalbo TODA',
      'phone': '+63 927 889 0012',
      'plateNo': '5589-NC',
      'status': 'Flagged (Dispute)',
      'verification': 91.0,
      'trips': 62,
      'rating': 4.2,
    },
    {
      'bodyNo': 'T-0855',
      'mtop': 'MTOP-LAO-2023-00855',
      'name': 'Nestor Valdez',
      'toda': 'Laoag Central TODA',
      'phone': '+63 908 776 5543',
      'plateNo': '1092-NA',
      'status': 'Overcharge Warning',
      'verification': 89.4,
      'trips': 78,
      'rating': 4.1,
    },
  ];

  // TODA Pila FIFO Queue Inspector Data
  final Map<String, List<Map<String, dynamic>>> _pilaQueues = {
    'TODA-01': [
      {'rank': 1, 'bodyNo': 'T-0142', 'name': 'Eduardo Castro', 'dwellMins': 4, 'status': 'Next to Board'},
      {'rank': 2, 'bodyNo': 'T-0520', 'name': 'Arturo Domingo', 'dwellMins': 9, 'status': 'Queued'},
      {'rank': 3, 'bodyNo': 'T-0855', 'name': 'Nestor Valdez', 'dwellMins': 14, 'status': 'Queued'},
      {'rank': 4, 'bodyNo': 'T-0912', 'name': 'Jaime Alcantara', 'dwellMins': 18, 'status': 'Queued'},
      {'rank': 5, 'bodyNo': 'T-1004', 'name': 'Crisanto Agbayani', 'dwellMins': 22, 'status': 'Queued'},
    ],
    'TODA-02': [
      {'rank': 1, 'bodyNo': 'T-0219', 'name': 'Rogelio Pascual', 'dwellMins': 2, 'status': 'Next to Board'},
      {'rank': 2, 'bodyNo': 'T-0388', 'name': 'Marcos Barba', 'dwellMins': 6, 'status': 'Queued'},
      {'rank': 3, 'bodyNo': 'T-0741', 'name': 'Emilio Farinas', 'dwellMins': 11, 'status': 'Queued'},
    ],
    'TODA-03': [
      {'rank': 1, 'bodyNo': 'T-0331', 'name': 'Ferdinand Corpuz', 'dwellMins': 5, 'status': 'Next to Board'},
      {'rank': 2, 'bodyNo': 'T-0662', 'name': 'Vicente Keon', 'dwellMins': 12, 'status': 'Queued'},
    ],
  };

  // Flagged 1:1 Face Verifications Queue
  final List<Map<String, dynamic>> _flaggedVerifications = [
    {
      'id': 'VER-2026-001',
      'phone_number': '+639174451029',
      'name': 'Maria Clara Santos',
      'role': 'rider',
      'idType': 'Student ID (MMSU CTE)',
      'similarity': 96.4,
      'latency': 1.12,
      'status': 'approved',
      'note': 'Valid 20% statutory student discount applied.',
    },
    {
      'id': 'VER-2026-002',
      'phone_number': '+639189923310',
      'name': 'Eduardo "Manong Eddie" Castro',
      'role': 'driver',
      'idType': 'Professional Driver\'s License',
      'similarity': 94.8,
      'latency': 1.45,
      'status': 'approved',
      'note': 'MINC Franchise #042 active & verified.',
    },
    {
      'id': 'VER-2026-003',
      'phone_number': '+639201124489',
      'name': 'Juan Delos Reyes',
      'role': 'driver',
      'idType': 'TODA MINC Permit',
      'similarity': 78.2,
      'latency': 1.60,
      'status': 'pending',
      'note': 'Manual review requested. Partial face shadow.',
    },
  ];

  // System Audit Trail
  final List<Map<String, dynamic>> _systemAuditLogs = [
    {'time': 'Today, 11:30 AM', 'actor': 'MINC Officer Santos', 'action': 'Sent Overcharge Warning Notice to Body #T-0855'},
    {'time': 'Today, 10:15 AM', 'actor': 'System Sentinel', 'action': 'Automated GPS Discrepancy Flagged on Trip TRP-9402'},
    {'time': 'Today, 09:00 AM', 'actor': 'Laoag Admin', 'action': 'Synced PostGIS Terminal Geofences with Supabase'},
    {'time': 'Yesterday', 'actor': 'TODA Inspector', 'action': 'Validated 14 Driver Face Verification Biometric IDs'},
  ];

  // Live Emergency SOS Sentinel State (Real-Time Driver Distress Beacons)
  final List<Map<String, dynamic>> _sosAlerts = [
    {
      'id': 'SOS-2026-089',
      'driver_name': 'Eduardo "Manong Eddie" Castro',
      'body_number': '#042',
      'plate_number': '7489-IN',
      'toda': 'Laoag Central Terminal TODA',
      'latitude': 18.1960,
      'longitude': 120.5935,
      'location_name': 'Gilbert Bridge / J.P. Rizal St (Zone 1)',
      'alert_reason': 'DRIVER_PANIC_BUTTON_ACTIVE_TRIP',
      'status': 'ACTIVE_DISPATCHED',
      'time_ago': '1 min ago',
      'created_at': DateTime.now().subtract(const Duration(minutes: 1)).toIso8601String(),
      'contact': '+63 917 554 9012',
    },
  ];
  StreamSubscription? _sosSubscription;

  @override
  void initState() {
    super.initState();
    _syncFromSupabase();
    _listenToSosAlerts();
  }

  @override
  void dispose() {
    _sosSubscription?.cancel();
    super.dispose();
  }

  void _listenToSosAlerts() {
    try {
      _sosSubscription = Supabase.instance.client
          .from('emergency_sos_alerts')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .listen((data) {
        if (mounted && data.isNotEmpty) {
          setState(() {
            for (final item in data) {
              final idStr = item['id'].toString();
              final existingIndex = _sosAlerts.indexWhere((a) => a['id'] == idStr);
              final parsed = {
                'id': idStr,
                'driver_name': item['driver_name'] ?? 'Tricycle Driver',
                'body_number': item['body_number'] ?? '#042',
                'plate_number': item['plate_number'] ?? '7489-IN',
                'toda': item['toda'] ?? 'Laoag Central Terminal TODA',
                'latitude': (item['latitude'] as num?)?.toDouble() ?? 18.1960,
                'longitude': (item['longitude'] as num?)?.toDouble() ?? 120.5935,
                'location_name': item['location_name'] ?? 'Laoag City Paratransit Route',
                'alert_reason': item['alert_reason'] ?? 'DRIVER_TRIGGERED_EMERGENCY_SOS',
                'status': item['status'] ?? 'ACTIVE_DISPATCHED',
                'time_ago': 'Just now',
                'created_at': item['created_at'] ?? DateTime.now().toIso8601String(),
                'contact': item['contact'] ?? '+63 917 554 9012',
              };
              if (existingIndex >= 0) {
                _sosAlerts[existingIndex] = parsed;
              } else {
                _sosAlerts.insert(0, parsed);
              }
            }
          });
        }
      });
    } catch (_) {}
  }

  void _resolveSosAlert(Map<String, dynamic> alert) async {
    setState(() {
      alert['status'] = 'RESOLVED';
      _systemAuditLogs.insert(0, {
        'time': 'Just now',
        'actor': 'MINC Emergency Dispatcher',
        'action': 'Resolved Distress Beacon for Driver ${alert['driver_name']} (${alert['body_number']})',
      });
    });
    try {
      await Supabase.instance.client
          .from('emergency_sos_alerts')
          .update({'status': 'RESOLVED'})
          .eq('driver_name', alert['driver_name']);
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Incident ${alert['id']} marked RESOLVED. Laoag PNP and TODA Dispatch stood down.'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    }
  }

  void _dispatchLaoagPnp(Map<String, dynamic> alert) {
    setState(() {
      _systemAuditLogs.insert(0, {
        'time': 'Just now',
        'actor': 'Command Dispatcher Santos',
        'action': 'Dispatched Laoag PNP Patrol Car to assist Driver ${alert['driver_name']} (${alert['body_number']}) at ${alert['location_name']}',
      });
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🚨 DISPATCH SENT TO LAOAG PNP (Hotline: 077-772-0256): Patrol unit responding to ${alert['location_name']}!'),
        backgroundColor: const Color(0xFFDC2626),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _simulateDriverSos() async {
    final id = 'SOS-${DateTime.now().millisecondsSinceEpoch % 10000}';
    final newAlert = {
      'id': id,
      'driver_name': 'Eduardo "Manong Eddie" Castro',
      'body_number': '#042',
      'plate_number': '7489-IN',
      'toda': 'Laoag Central Terminal TODA',
      'latitude': 18.1960,
      'longitude': 120.5935,
      'location_name': 'Gilbert Bridge / J.P. Rizal St (Zone 1)',
      'alert_reason': 'DRIVER_PANIC_BUTTON_ACTIVE_TRIP',
      'status': 'ACTIVE_DISPATCHED',
      'time_ago': 'Just now',
      'created_at': DateTime.now().toIso8601String(),
      'contact': '+63 917 554 9012',
    };
    setState(() {
      _sosAlerts.removeWhere((a) => a['id'] == id);
      _sosAlerts.insert(0, newAlert);
      _systemAuditLogs.insert(0, {
        'time': 'Just now',
        'actor': 'Live Telemetry Sentinel',
        'action': 'Received High-Priority SOS Beacon from Body #042 at Gilbert Bridge',
      });
    });

    try {
      await Supabase.instance.client.from('emergency_sos_alerts').insert({
        'driver_name': newAlert['driver_name'],
        'latitude': newAlert['latitude'],
        'longitude': newAlert['longitude'],
        'alert_reason': newAlert['alert_reason'],
        'status': 'ACTIVE_DISPATCHED',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚨 LIVE SOS RECEIVED: Driver Eduardo Castro (#042) triggered distress beacon near Gilbert Bridge!'),
          backgroundColor: Color(0xFFDC2626),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  void _showSosIncidentModal(Map<String, dynamic> alert) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFCA5A5)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFDC2626),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DISTRESS BEACON: ${alert['id']}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF991B1B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Status: ${alert['status']} • Triggered: ${alert['time_ago']}',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFFB91C1C), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                          border: Border.all(color: const Color(0xFFDC2626), width: 2),
                        ),
                        child: const Center(child: Text('🛺', style: TextStyle(fontSize: 24))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alert['driver_name'],
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Body #${alert['body_number']} • Plate: ${alert['plate_number']} • ${alert['toda']}',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Contact: ${alert['contact']}',
                              style: const TextStyle(color: Color(0xFF059669), fontSize: 11.5, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Live Incident Telemetry & PostGIS GPS Location', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A))),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.gps_fixed_rounded, color: Color(0xFF38BDF8), size: 16),
                              SizedBox(width: 8),
                              Text('GPS COORDINATES', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, fontWeight: FontWeight.w800)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFF0284C7), borderRadius: BorderRadius.circular(6)),
                            child: const Text('Accuracy: ±4.2m', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${alert['latitude']}° N, ${alert['longitude']}° E',
                        style: const TextStyle(fontFamily: 'Courier', color: Color(0xFF38BDF8), fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Landmark: ${alert['location_name']}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const Divider(color: Colors.white12, height: 16),
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFF87171), size: 15),
                          const SizedBox(width: 6),
                          Text(
                            'Beacon Reason: ${alert['alert_reason']}',
                            style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'MINC Operational Protocol: Tapping "Dispatch Laoag PNP" logs an official emergency incident and alerts the Laoag City Police Station on P. Gomez St.',
                          style: TextStyle(color: Color(0xFF92400E), fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _resolveSosAlert(alert);
            },
            icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
            label: const Text('Mark Incident Resolved'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF059669),
              side: const BorderSide(color: Color(0xFFA7F3D0)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _dispatchLaoagPnp(alert);
            },
            icon: const Icon(Icons.local_police_rounded, size: 16),
            label: const Text('Dispatch Laoag PNP Patrol (077-772-0256)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _syncFromSupabase() async {
    setState(() => _isSyncing = true);
    try {
      final res = await Supabase.instance.client
          .from('fare_guide_table')
          .select()
          .order('id', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res != null) {
        setState(() {
          _regFirstKm = (res['regular_first_km_fare'] as num?)?.toDouble() ?? _regFirstKm;
          _discFirstKm = (res['discounted_first_km_fare'] as num?)?.toDouble() ?? _discFirstKm;
          _baseDistKm = (res['base_distance_km'] as num?)?.toDouble() ?? _baseDistKm;
          _succKm = (res['succeeding_km_rate'] as num?)?.toDouble() ?? _succKm;
        });
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isSyncing = false);
    }
  }

  Future<void> _saveFareGuideToSupabase() async {
    setState(() => _isSyncing = true);
    try {
      await Supabase.instance.client.from('fare_guide_table').insert({
        'ordinance_label': 'City Ordinance No. 2023-005 (₱$_regFirstKm / ₱$_discFirstKm)',
        'regular_first_km_fare': _regFirstKm,
        'discounted_first_km_fare': _discFirstKm,
        'succeeding_km_rate': _succKm,
        'base_distance_km': _baseDistKm,
        'statutory_discount_share_rate': 0.20,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Fare Guide updated in Supabase cloud! Pushed to all mobile passenger apps.'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved locally. (Cloud Sync notice: $e)'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    }
    if (mounted) setState(() => _isSyncing = false);
  }

  // Calculate dynamic simulated hourly demand based on Hour + Scenario
  double _getDynamicZoneDemand(Map<String, dynamic> zone) {
    final base = (zone['baseForecast'] as num).toDouble();
    double hourFactor = 1.0;

    // Time-of-day curve (Laoag paratransit mobility cycle)
    if (_simulatedHour >= 6 && _simulatedHour < 8.5) {
      hourFactor = 1.45; // Morning school/market rush
    } else if (_simulatedHour >= 8.5 && _simulatedHour < 11.5) {
      hourFactor = 0.95; // Mid-morning baseline
    } else if (_simulatedHour >= 11.5 && _simulatedHour < 13.5) {
      hourFactor = 1.25; // Lunch surge
    } else if (_simulatedHour >= 13.5 && _simulatedHour < 16.5) {
      hourFactor = 0.90; // Mid-afternoon
    } else if (_simulatedHour >= 16.5 && _simulatedHour < 18.5) {
      hourFactor = 1.50; // University & office dismissal peak
    } else if (_simulatedHour >= 18.5 && _simulatedHour < 21.0) {
      hourFactor = 0.65; // Evening cooldown
    } else {
      hourFactor = 0.15; // Night hours
    }

    // Scenario modifiers
    double scenarioFactor = 1.0;
    if (_activeScenario == 'Morning Rush (07:30)') {
      if (zone['code'] == 'Z01' || zone['code'] == 'Z02' || zone['code'] == 'Z09') {
        scenarioFactor = 1.55;
      }
    } else if (_activeScenario == 'University Dismissal (17:00)') {
      if (zone['code'] == 'Z02' || zone['code'] == 'Z07' || zone['code'] == 'Z03') {
        scenarioFactor = 1.65;
      }
    } else if (_activeScenario == 'Monsoon Rain Surge') {
      scenarioFactor = 1.40; // Heavy rainfall surge
    } else if (_activeScenario == 'Night Shift (k=5 PIA)') {
      scenarioFactor = 0.12;
    }

    final calculated = base * hourFactor * scenarioFactor;
    return double.parse(calculated.toStringAsFixed(1));
  }

  // Export ML dataset in JSON and CSV
  void _exportMlDataset(String format) {
    final buffer = StringBuffer();
    if (format == 'CSV') {
      buffer.writeln('zone_code,zone_name,latitude,longitude,hour,demand_forecast,actual_pilot_trips,k5_privacy_status');
      for (final z in _mlZones) {
        final demand = _getDynamicZoneDemand(z);
        final k5 = demand < 5 ? 'SUPPRESSED_K5' : 'VISIBLE';
        buffer.writeln('${z['code']},"${z['name']}",${z['lat']},${z['lng']},${_simulatedHour.toInt()},$demand,${z['trips']},$k5');
      }
    } else {
      final list = _mlZones.map((z) {
        final demand = _getDynamicZoneDemand(z);
        return {
          'zone_code': z['code'],
          'zone_name': z['name'],
          'latitude': z['lat'],
          'longitude': z['lng'],
          'hour': _simulatedHour.toInt(),
          'predicted_demand': demand,
          'k5_anonymized': demand < 5,
        };
      }).toList();
      buffer.write(const JsonEncoder.withIndent('  ').convert({
        'metadata': {
          'city': 'Laoag City, Ilocos Norte',
          'ordinance': 'Laoag City Ord. 2023-005',
          'total_zone_hours': 6720,
          'mase': 0.5726,
          'wmape': 0.0694,
        },
        'records': list,
      }));
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.file_download_done_rounded, color: Color(0xFF059669)),
            const SizedBox(width: 10),
            Text('ML Dataset Exported ($format)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Successfully generated $format dataset for Hour ${_simulatedHour.toInt()}:00 across all 10 Laoag zones. Data copied to clipboard!'),
              const SizedBox(height: 12),
              Container(
                height: 180,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    buffer.toString(),
                    style: const TextStyle(fontFamily: 'Courier', fontSize: 11, color: Color(0xFF38BDF8)),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Exported $format data copied to clipboard! Ready for Python/Pandas.')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy to Clipboard'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  // MINC Summons / Warning Generator Dialog
  void _showMincSummonsDialog(Map<String, dynamic> trip) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.gavel_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 10),
            Text('City of Laoag — MINC Summons Notice', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: SizedBox(
          width: 540,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'VIOLATION OF LAOAG CITY ORDINANCE NO. 2023-005\nExcess Fare Overcharging Detected on Trip ${trip['id']}',
                        style: const TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text('Driver Name: ${trip['driver']} (Body Number: ${trip['bodyNo']})', style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('TODA Affiliation: ${trip['toda']}'),
              Text('Route: ${trip['origin']} → ${trip['destination']}'),
              Text('GPS Road Distance: ${trip['distanceKm']} km'),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Legal Ordinance Fare: ₱${trip['expectedFare'].toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                  Text('Collected Fare: ₱${trip['collectedFare'].toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                ],
              ),
              const SizedBox(height: 6),
              Text('Unlawful Overcharge Discrepancy: +₱${trip['overchargeAmount']?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFDC2626))),
              const SizedBox(height: 12),
              const Text(
                'ORDER: You are hereby directed to appear before the Motorized Tricycle Franchising and Regulatory Board (MINC Office, Laoag City Hall) within 72 hours for formal adjudication.',
                style: TextStyle(fontSize: 11.5, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Dismiss')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✓ Official MINC Summons issued to ${trip['driver']} (${trip['bodyNo']})! Logged to City Records.'),
                  backgroundColor: const Color(0xFFDC2626),
                ),
              );
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Issue Official Notice'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          // 1. LEFT SIDEBAR (Krisp Style Shell)
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                // Brand Header with Official Logo
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            'assets/images/app_logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.local_taxi_rounded,
                              color: Color(0xFF059669),
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PasadaNorte',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Laoag MINC Admin',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF059669),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _syncFromSupabase,
                        tooltip: 'Sync Supabase Cloud',
                        icon: _isSyncing
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF059669)))
                            : Icon(Icons.sync_rounded, size: 18, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade200),

                // Sidebar Navigation Links (All 10 Dedicated Views)
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    children: [
                      _buildSidebarSectionLabel('PASADANORTE ORGANIZATION'),
                      _buildSidebarItem(Icons.auto_graph_rounded, 'Analytics'),
                      _buildSidebarItem(
                        Icons.desktop_windows_outlined,
                        'Live Monitoring',
                        badge: _sosAlerts.any((a) => a['status'] == 'ACTIVE_DISPATCHED')
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '🚨 SOS',
                                  style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                                ),
                              )
                            : null,
                      ),
                      _buildSidebarItem(Icons.assignment_outlined, 'Live Dispatch Audit'),
                      _buildSidebarItem(Icons.format_list_numbered_rounded, 'TODA Pila Queue Board'),

                      const SizedBox(height: 16),
                      _buildSidebarSectionLabel('PARATRANSIT OPERATIONS'),
                      _buildSidebarItem(Icons.psychology_outlined, 'ML Demand Simulator'),
                      _buildSidebarItem(Icons.map_outlined, 'Laoag 10-Zone Map & Heatmap'),
                      _buildSidebarItem(Icons.local_taxi_outlined, 'TODA Stations'),
                      _buildSidebarItem(Icons.payments_outlined, 'Fare Matrix (Ord. 2023-005)'),

                      const SizedBox(height: 16),
                      _buildSidebarSectionLabel('ORGANIZATION MANAGEMENT'),
                      _buildSidebarItem(Icons.people_outline_rounded, 'Directory & Drivers'),
                      _buildSidebarItem(Icons.verified_user_outlined, '1:1 Face Verifications'),
                      _buildSidebarItem(Icons.settings_outlined, 'Settings & Compliance'),
                    ],
                  ),
                ),

                // Bottom Admin Profile Footer
                Divider(height: 1, color: Colors.grey.shade200),
                Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 17,
                        backgroundColor: Color(0xFFE0E7FF),
                        child: Text('PN', style: TextStyle(color: Color(0xFF4338CA), fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Laoag City LGU', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                            Text('TODA & MINC Officer', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                          ],
                        ),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. MAIN CONTENT AREA
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Bar with responsive actions
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getSectionIcon(_selectedSection),
                        color: const Color(0xFF0F172A),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _selectedSection,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      Flexible(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          reverse: true,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Live Emergency SOS Status Badge or Test Trigger
                              if (_sosAlerts.any((a) => a['status'] == 'ACTIVE_DISPATCHED'))
                                GestureDetector(
                                  onTap: () {
                                    final alert = _sosAlerts.firstWhere((a) => a['status'] == 'ACTIVE_DISPATCHED');
                                    _showSosIncidentModal(alert);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFF87171)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFDC2626),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '🚨 SOS: ${_sosAlerts.firstWhere((a) => a['status'] == 'ACTIVE_DISPATCHED')['driver_name']} (#042)',
                                          style: const TextStyle(
                                            color: Color(0xFFDC2626),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                OutlinedButton.icon(
                                  onPressed: _simulateDriverSos,
                                  icon: const Icon(Icons.emergency_rounded, size: 15, color: Color(0xFFDC2626)),
                                  label: const Text('Test Driver SOS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () => _exportMlDataset('CSV'),
                                icon: const Icon(Icons.table_view_rounded, size: 16),
                                label: const Text('Export CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF059669),
                                  side: const BorderSide(color: Color(0xFFA7F3D0)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () => _exportMlDataset('JSON'),
                                icon: const Icon(Icons.code_rounded, size: 16),
                                label: const Text('Export JSON', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF059669),
                                  side: const BorderSide(color: Color(0xFFA7F3D0)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              TextButton.icon(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('PasadaNorte Web Admin Portal v2.0 • Active Session (Supabase PostGIS Live).'),
                                      backgroundColor: Color(0xFF059669),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.help_outline_rounded, size: 16),
                                label: const Text('MINC Help', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Emergency SOS Live Incident Sentinel Banner
                _buildEmergencySosSentinelBanner(),

                // Top Sub-Tabs Navigation (Krisp Analytics Sub-Tabs)
                if (_selectedSection == 'Analytics')
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildSubTab(0, 'Organization Overview'),
                          _buildSubTab(1, 'ML Demand Radar'),
                          _buildSubTab(2, 'TODA Pila Queues'),
                          _buildSubTab(3, 'Fare Compliance (Ord. 2023-005)'),
                          _buildSubTab(4, 'Fleet & Tricycles'),
                          _buildSubTab(5, 'Training Data Export'),
                        ],
                      ),
                    ),
                  ),

                // Main Scrollable View Area
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: _buildCurrentSectionView(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSectionIcon(String section) {
    switch (section) {
      case 'Analytics':
        return Icons.auto_graph_rounded;
      case 'Live Monitoring':
        return Icons.desktop_windows_outlined;
      case 'Live Dispatch Audit':
        return Icons.assignment_outlined;
      case 'TODA Pila Queue Board':
        return Icons.format_list_numbered_rounded;
      case 'ML Demand Simulator':
        return Icons.psychology_outlined;
      case 'Laoag 10-Zone Map & Heatmap':
        return Icons.map_outlined;
      case 'TODA Stations':
        return Icons.local_taxi_outlined;
      case 'Fare Matrix (Ord. 2023-005)':
        return Icons.payments_outlined;
      case 'Directory & Drivers':
        return Icons.people_outline_rounded;
      case '1:1 Face Verifications':
        return Icons.verified_user_outlined;
      case 'Settings & Compliance':
        return Icons.settings_outlined;
      default:
        return Icons.dashboard_rounded;
    }
  }

  Widget _buildCurrentSectionView() {
    switch (_selectedSection) {
      case 'Analytics':
        if (_analyticsSubTab == 1) return _buildMlSimulatorView();
        if (_analyticsSubTab == 2) return _buildTodaQueueBoardView();
        if (_analyticsSubTab == 3) return _buildDispatchAuditView();
        if (_analyticsSubTab == 4) return _buildDirectoryView();
        if (_analyticsSubTab == 5) return _buildTrainingDataExportTab();
        return _buildAnalyticsDashboardView();
      case 'Live Monitoring':
        return _buildLiveMonitoringView();
      case 'Live Dispatch Audit':
        return _buildDispatchAuditView();
      case 'TODA Pila Queue Board':
        return _buildTodaQueueBoardView();
      case 'ML Demand Simulator':
        return _buildMlSimulatorView();
      case 'Laoag 10-Zone Map & Heatmap':
        return _buildLaoagMapCanvasView();
      case 'TODA Stations':
        return _buildTodaStationsView();
      case 'Fare Matrix (Ord. 2023-005)':
        return _buildFareMatrixView();
      case 'Directory & Drivers':
        return _buildDirectoryView();
      case '1:1 Face Verifications':
        return _buildFaceVerificationsView();
      case 'Settings & Compliance':
        return _buildSettingsView();
      default:
        return _buildAnalyticsDashboardView();
    }
  }

  // ===========================================================================
  // 1. KRISP-STYLE ANALYTICS OVERVIEW
  // ===========================================================================
  Widget _buildAnalyticsDashboardView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Date Filter Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics_rounded, color: Color(0xFF059669), size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'PasadaNorte - $_selectedDateRange',
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              DropdownButton<String>(
                value: _selectedDateRange,
                underline: const SizedBox(),
                items: ['Jun 2026', 'Today (Live)', 'Last 7 Days', 'Full 8-Week Pilot']
                    .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedDateRange = val);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // KPI Metric Cards - Row 1
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return GridView.count(
              crossAxisCount: isWide ? 3 : 1,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: isWide ? 1.6 : 2.2,
              children: [
                _buildKrispMetricCard(
                  title: 'Completed Trips',
                  value: '4,565',
                  dateLabel: 'June 30, 2026',
                  trendLabel: '↑ 100% vs. Baseline: 45',
                  trendPositive: true,
                  sparklineType: SparklineType.upwardSmooth,
                ),
                _buildKrispMetricCard(
                  title: 'Active Tricycles on Duty',
                  value: '90',
                  dateLabel: 'June 30, 2026',
                  trendLabel: '↑ ∞% vs. June 30: 0',
                  trendPositive: true,
                  sparklineType: SparklineType.steadyRise,
                ),
                _buildKrispMetricCard(
                  title: 'Average Pila Dwell Time',
                  value: '3.8m',
                  dateLabel: 'June 30, 2026',
                  trendLabel: '↓ 64% vs. Manual: 10.5m',
                  trendPositive: true,
                  sparklineType: SparklineType.downwardEfficiency,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),

        // KPI Metric Cards - Row 2
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return GridView.count(
              crossAxisCount: isWide ? 2 : 1,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: isWide ? 2.4 : 2.2,
              children: [
                _buildKrispMetricCard(
                  title: 'Deployment Rate',
                  value: '11.11%',
                  dateLabel: 'June 30, 2026',
                  trendLabel: '↑ ∞% vs. June 30: 0.00%',
                  trendPositive: true,
                  sparklineType: SparklineType.mildRise,
                ),
                _buildKrispMetricCard(
                  title: 'TODA Digital Pila Adoption Rate',
                  value: '88.50%',
                  dateLabel: 'June 30, 2026',
                  trendLabel: '↑ 78.5% vs. Week 1: 10.00%',
                  trendPositive: true,
                  sparklineType: SparklineType.steadyRise,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),

        // Main Trend Chart
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 10,
                children: [
                  const Text(
                    'Deployment & Adoption Trends (%)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLegendDot(const Color(0xFFF97316), 'Deployment Rate'),
                      const SizedBox(width: 16),
                      _buildLegendDot(const Color(0xFF3B82F6), 'Adoption Rate'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 220,
                width: double.infinity,
                child: CustomPaint(painter: _KrispTrendChartPainter()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Quick Jump to Map and ML Simulator
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _selectedSection = 'ML Demand Simulator'),
                icon: const Icon(Icons.psychology_outlined),
                label: const Text('Open Interactive ML Demand Simulator'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _selectedSection = 'Laoag 10-Zone Map & Heatmap'),
                icon: const Icon(Icons.map_outlined),
                label: const Text('View Laoag 10-Zone Spatial Map'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // 2. INTERACTIVE ML DEMAND SCENARIO SIMULATOR (Recommendation 3)
  // ===========================================================================
  Widget _buildMlSimulatorView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Simulator Controls Header Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Interactive ML Demand Scenario Simulator',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Simulate spatial-temporal passenger demand for 10 Laoag City zones across operating hours.',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Text(
                      'Hour ${_simulatedHour.toInt().toString().padLeft(2, '0')}:00 • ${_simulatedHour >= 12 ? 'PM' : 'AM'}',
                      style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF059669), fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Hour Slider
              const Text('Time-of-Day Slider (00:00 to 23:00):', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Slider(
                value: _simulatedHour,
                min: 0.0,
                max: 23.0,
                divisions: 23,
                activeColor: const Color(0xFF059669),
                label: '${_simulatedHour.toInt()}:00',
                onChanged: (val) => setState(() => _simulatedHour = val),
              ),

              // Scenario Presets Buttons
              const SizedBox(height: 10),
              const Text('Scenario Presets:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildScenarioChip('Normal', Icons.schedule_rounded),
                  _buildScenarioChip('Morning Rush (07:30)', Icons.wb_sunny_rounded),
                  _buildScenarioChip('University Dismissal (17:00)', Icons.school_rounded),
                  _buildScenarioChip('Monsoon Rain Surge', Icons.cloud_rounded),
                  _buildScenarioChip('Night Shift (k=5 PIA)', Icons.nightlight_round),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 4 Evaluation Metrics Badges
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 850;
            return GridView.count(
              crossAxisCount: isWide ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: isWide ? 2.5 : 2.0,
              children: [
                _buildMlMetricBadge('MASE Score', '0.5726', 'Target < 1.00 (Beats Baseline)', const Color(0xFF10B981)),
                _buildMlMetricBadge('RMSE Error', '1.7146', 'Root Mean Square Error', const Color(0xFF3B82F6)),
                _buildMlMetricBadge('WMAPE %', '6.94%', 'Target <= 20.0% satisfied', const Color(0xFF8B5CF6)),
                _buildMlMetricBadge('Non-Zero MAPE', '9.26%', 'High-demand zone precision', const Color(0xFFF59E0B)),
              ],
            );
          },
        ),
        const SizedBox(height: 20),

        // 10 Zones Dynamic Table with Privacy Suppression Indicator
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Laoag City 10 Zone Demand Forecasts (Live Evaluated)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  OutlinedButton.icon(
                    onPressed: () => _exportMlDataset('CSV'),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Export Simulated CSV'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth > 700 ? constraints.maxWidth : 700),
                      child: Table(
                        columnWidths: const {
                          0: FixedColumnWidth(65),
                          1: FlexColumnWidth(3),
                          2: FlexColumnWidth(1.2),
                          3: FlexColumnWidth(1.6),
                          4: FlexColumnWidth(2.0),
                        },
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                            children: const [
                              Padding(padding: EdgeInsets.all(10), child: Text('ZONE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                              Padding(padding: EdgeInsets.all(10), child: Text('LANDMARK CLUSTER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                              Padding(padding: EdgeInsets.all(10), child: Text('PILOT TOTAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                              Padding(padding: EdgeInsets.all(10), child: Text('HOUR DEMAND', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                              Padding(padding: EdgeInsets.all(10), child: Text('ISO 25010 PRIVACY STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                            ],
                          ),
                          ..._mlZones.map((z) {
                            final demand = _getDynamicZoneDemand(z);
                            final isK5Suppressed = demand < 5.0;

                            return TableRow(
                              children: [
                                Padding(padding: const EdgeInsets.all(10), child: Text(z['code'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                                Padding(padding: const EdgeInsets.all(10), child: Text(z['name'], style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                                Padding(padding: const EdgeInsets.all(10), child: Text('${z['trips']}', style: const TextStyle(fontSize: 12))),
                                Padding(padding: const EdgeInsets.all(10), child: Text('${demand.toStringAsFixed(1)} req/h', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isK5Suppressed ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isK5Suppressed ? '🔒 Protected (k < 5 PIA)' : '✓ High-Confidence Broadcast',
                                      style: TextStyle(
                                        color: isK5Suppressed ? const Color(0xFFB45309) : const Color(0xFF059669),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScenarioChip(String label, IconData icon) {
    final isSelected = _activeScenario == label;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF059669)),
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF059669),
      labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 12),
      onSelected: (val) {
        if (val) {
          setState(() {
            _activeScenario = label;
            if (label == 'Morning Rush (07:30)') _simulatedHour = 7.5;
            if (label == 'University Dismissal (17:00)') _simulatedHour = 17.0;
            if (label == 'Night Shift (k=5 PIA)') _simulatedHour = 22.0;
          });
        }
      },
    );
  }

  // ===========================================================================
  // 3. INTERACTIVE LAOAG 10-ZONE MAP & HEATMAP (Recommendation 2)
  // ===========================================================================
  Widget _buildLaoagMapCanvasView() {
    final selectedZone = _mlZones.firstWhere((z) => z['code'] == _selectedZoneCode, orElse: () => _mlZones.first);
    final selectedDemand = _getDynamicZoneDemand(selectedZone);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Laoag City 10-Zone Spatial Map & Corridor Heatmap', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text('Visualizing paratransit demand corridors, Padsan River crossings, and TODA geofences.', style: TextStyle(color: Colors.grey)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(8)),
              child: Text('Selected: ${selectedZone['code']} — ${selectedZone['name']}', style: const TextStyle(color: Color(0xFF0369A1), fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Interactive Map Canvas
        Container(
          width: double.infinity,
          height: 420,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Stack(
            children: [
              // Custom Map Painter (River, Arterials, Zones)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CustomPaint(
                  size: const Size(double.infinity, 420),
                  painter: _LaoagMapPainter(
                    zones: _mlZones,
                    selectedCode: _selectedZoneCode,
                    getDemand: _getDynamicZoneDemand,
                  ),
                ),
              ),

              // Interactive Zone Click Overlay
              LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: _mlZones.map((z) {
                      final demand = _getDynamicZoneDemand(z);
                      final px = z['x'] * constraints.maxWidth;
                      final py = z['y'] * constraints.maxHeight;
                      final isSelected = z['code'] == _selectedZoneCode;

                      return Positioned(
                        left: px - 28,
                        top: py - 28,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedZoneCode = z['code']),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF059669) : Colors.white.withValues(alpha: 0.90),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                              border: Border.all(
                                color: isSelected ? Colors.white : (z['color'] as Color),
                                width: isSelected ? 3 : 2,
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    z['code'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                      color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                   Text(
                                    demand < 5 ? '<5' : '${demand.toInt()}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white70
                                          : (demand < 5 ? Colors.orange.shade800 : Colors.grey.shade700),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              // Map Legend Box
              Positioned(
                bottom: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Laoag City Geographic Legend', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Row(children: [
                        Container(width: 14, height: 4, color: const Color(0xFF38BDF8)),
                        const SizedBox(width: 8),
                        const Text('Padsan River & Gilbert Bridge', style: TextStyle(fontSize: 10)),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        const Text('High Demand (>25 req/h)', style: TextStyle(fontSize: 10)),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF94A3B8), shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        const Text('k < 5 req/h: Privacy Masked (RA 10173)', style: TextStyle(fontSize: 10, color: Color(0xFF475569))),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Selected Zone Detail Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on_rounded, color: Color(0xFF059669), size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${selectedZone['code']} — ${selectedZone['name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('Latitude: ${selectedZone['lat']} • Longitude: ${selectedZone['lng']} • Historical Trips: ${selectedZone['trips']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    selectedDemand < 5
                        ? '<5 req/hr (Suppressed)'
                        : '${selectedDemand.toStringAsFixed(1)} req/hr',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: selectedDemand < 5
                          ? const Color(0xFFD97706)
                          : const Color(0xFF059669),
                    ),
                  ),
                  Text(
                    selectedDemand < 5
                        ? 'RA 10173: k-Anonymity Protected'
                        : 'Active Dispatch Corridor',
                    style: TextStyle(
                      color: selectedDemand < 5
                          ? Colors.orange.shade800
                          : Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 4. LIVE DISPATCH AUDIT & ANTI-OVERCHARGING SENTINEL (Recommendation 1 & 4)
  // ===========================================================================
  Widget _buildDispatchAuditView() {
    final filtered = _dispatchTrips.where((t) {
      final matchesSearch = t['rider'].toString().toLowerCase().contains(_dispatchSearchQuery.toLowerCase()) ||
          t['driver'].toString().toLowerCase().contains(_dispatchSearchQuery.toLowerCase()) ||
          t['bodyNo'].toString().toLowerCase().contains(_dispatchSearchQuery.toLowerCase()) ||
          t['id'].toString().toLowerCase().contains(_dispatchSearchQuery.toLowerCase());
      if (_dispatchFilter == 'Overcharged') return matchesSearch && t['status'] == 'OVERCHARGED';
      if (_dispatchFilter == 'Compliant') return matchesSearch && t['status'] == 'COMPLIANT';
      return matchesSearch;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Live Dispatch Audit & Anti-Overcharging Sentinel', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Automatic GPS fare discrepancy detection enforcing Laoag City Ordinance No. 2023-005.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 18),

        // Search and Filter Bar
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by Trip ID, Rider, Driver name, or Body Number...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onChanged: (val) => setState(() => _dispatchSearchQuery = val),
              ),
            ),
            const SizedBox(width: 14),
            DropdownButton<String>(
              value: _dispatchFilter,
              items: ['All', 'Compliant', 'Overcharged']
                  .map((f) => DropdownMenuItem(value: f, child: Text('Filter: $f Trips', style: const TextStyle(fontWeight: FontWeight.w700))))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _dispatchFilter = val);
              },
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Dispatch Trips Table
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              ...filtered.map((trip) {
                final isOvercharged = trip['status'] == 'OVERCHARGED';

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isOvercharged ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isOvercharged ? Icons.report_problem_rounded : Icons.check_circle_rounded,
                          color: isOvercharged ? const Color(0xFFDC2626) : const Color(0xFF059669),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('${trip['id']} • ${trip['bodyNo']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isOvercharged ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isOvercharged ? 'OVERCHARGED (+₱${trip['overchargeAmount']?.toStringAsFixed(2)})' : 'COMPLIANT',
                                    style: TextStyle(
                                      color: isOvercharged ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text('Rider: ${trip['rider']} (${trip['riderRole']}) ➔ Driver: ${trip['driver']}', style: const TextStyle(fontSize: 12.5)),
                            Text('Route: ${trip['origin']} ➔ ${trip['destination']} (${trip['distanceKm']} km)', style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('₱${trip['collectedFare'].toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isOvercharged ? const Color(0xFFDC2626) : const Color(0xFF0F172A))),
                          Text('Expected: ₱${trip['expectedFare'].toStringAsFixed(2)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                          if (isOvercharged)
                            TextButton(
                              onPressed: () => _showMincSummonsDialog(trip),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFDC2626),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text('Issue MINC Notice ➔', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 5. MINC DRIVERS & FRANCHISE DIRECTORY (Recommendation 1)
  // ===========================================================================
  Widget _buildDirectoryView() {
    final filtered = _driverDirectory.where((d) {
      final matchesSearch = d['name'].toString().toLowerCase().contains(_driverSearchQuery.toLowerCase()) ||
          d['bodyNo'].toString().toLowerCase().contains(_driverSearchQuery.toLowerCase()) ||
          d['plateNo'].toString().toLowerCase().contains(_driverSearchQuery.toLowerCase());
      if (_driverTodaFilter != 'All') return matchesSearch && d['toda'] == _driverTodaFilter;
      return matchesSearch;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('MINC Tricycle Operators & Drivers Association Directory', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Official registry of authorized Laoag City Motorized Tricycle Operator Permits (MTOP).', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 18),

        // Filter Bar
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by Body Number, Driver Name, or Plate Number...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onChanged: (val) => setState(() => _driverSearchQuery = val),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Drivers Directory Cards
        ...filtered.map((driver) {
          final isFlagged = driver['status'].toString().contains('Warning') || driver['status'].toString().contains('Flagged');

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF059669).withValues(alpha: 0.12),
                  child: Text(
                    driver['bodyNo'].toString().replaceAll('T-', '#'),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF059669)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(driver['name'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isFlagged ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              driver['status'],
                              style: TextStyle(
                                color: isFlagged ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                fontWeight: FontWeight.w700,
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text('Franchise: ${driver['mtop']} • Plate: ${driver['plateNo']} • ${driver['toda']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      Text('Mobile: ${driver['phone']} • Completed Trips: ${driver['trips']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_user_rounded, color: Color(0xFF059669), size: 16),
                        const SizedBox(width: 4),
                        Text('${driver['verification']}% Match', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF059669), fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('★ ${driver['rating']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFFF59E0B))),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ===========================================================================
  // 6. TODA PILA QUEUE BOARD (Recommendation 1)
  // ===========================================================================
  Widget _buildTodaQueueBoardView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('TODA Terminal Pila FIFO Dispatch Queue Board', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Live First-In First-Out queuing board with driver dwell timers and anti-jump enforcement.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 18),

        ..._terminals.map((term) {
          final queue = _pilaQueues[term['code']] ?? [];

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_taxi_rounded, color: Color(0xFF059669), size: 22),
                        const SizedBox(width: 10),
                        Text(term['name'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${queue.length} in queue', style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w800, fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (queue.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text('No tricycles currently queued in this station geofence.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  )
                else
                  ...queue.map((item) {
                    final isRankOne = item['rank'] == 1;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isRankOne ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isRankOne ? const Color(0xFFBBF7D0) : Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isRankOne ? const Color(0xFF059669) : Colors.grey.shade300,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '#${item['rank']}',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: isRankOne ? Colors.white : Colors.black87),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${item['name']} (${item['bodyNo']})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                                Text('Dwell time: ${item['dwellMins']} mins in queue', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isRankOne ? const Color(0xFFD1FAE5) : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item['status'],
                              style: TextStyle(
                                color: isRankOne ? const Color(0xFF059669) : Colors.grey.shade700,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ===========================================================================
  // 7. TODA GEOFENCES VIEW
  // ===========================================================================
  Widget _buildTodaStationsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('TODA Terminal Geofence Calibration (Supabase PostGIS)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Configure GPS virtual fences to detect tricycle queue arrival and prevent queue jump exploitation.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 18),
        ..._terminals.map((t) {
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(t['name'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    Text('Radius: ${t['radius'].toStringAsFixed(0)} meters', style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w700)),
                  ],
                ),
                Slider(
                  value: (t['radius'] as double).clamp(10.0, 50.0),
                  min: 10.0,
                  max: 50.0,
                  divisions: 8,
                  activeColor: const Color(0xFF059669),
                  label: '${t['radius'].toStringAsFixed(0)}m',
                  onChanged: (val) {
                    setState(() => t['radius'] = val);
                  },
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ===========================================================================
  // 8. FARE MATRIX VIEW (City Ordinance 2023-005)
  // ===========================================================================
  Widget _buildFareMatrixView() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Laoag City Ordinance No. 2023-005 Fare Matrix', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Live cloud configuration synced to all passenger and driver phones.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildFareInput('Regular First 1.0 km (₱)', _regFirstKm, (v) => _regFirstKm = v)),
              const SizedBox(width: 16),
              Expanded(child: _buildFareInput('Discounted First 1.0 km (20% Student/PWD)', _discFirstKm, (v) => _discFirstKm = v)),
              const SizedBox(width: 16),
              Expanded(child: _buildFareInput('Succeeding Per-Km Rate (₱)', _succKm, (v) => _succKm = v)),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _saveFareGuideToSupabase,
            icon: const Icon(Icons.cloud_upload_rounded),
            label: const Text('Save Fare Updates to Cloud'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFareInput(String label, double val, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: val.toStringAsFixed(2),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onChanged: (str) {
            final parsed = double.tryParse(str);
            if (parsed != null) onChanged(parsed);
          },
        ),
      ],
    );
  }

  // ===========================================================================
  // 9. 1:1 FACE VERIFICATIONS VIEW (ISO/IEC 19795-1)
  // ===========================================================================
  String _maskPhoneNumber(String phone) {
    if (phone.length <= 6) return phone;
    final start = phone.substring(0, phone.length - 7);
    final end = phone.substring(phone.length - 3);
    return '$start *** *$end';
  }

  // ===========================================================================
  // 9. 1:1 FACE VERIFICATIONS VIEW (ISO/IEC 19795-1 & RA 10173 COMPLIANT)
  // ===========================================================================
  Widget _buildFaceVerificationsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('1:1 Face Verification Review Queue (ISO/IEC 19795-1)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Biometric verification queue ensuring zero fake accounts and validated student/senior/driver discounts.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 14),

        // RA 10173 & NPC Circular 2023-03 Biometric Compliance Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.privacy_tip_rounded, color: Color(0xFF16A34A), size: 28),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RA 10173 (Data Privacy Act of 2012) & NPC Circular 2023-03 Compliance',
                      style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF15803D), fontSize: 13.5),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• Private Storage Buckets: Driver licenses, OSCA/PWD IDs, and face scans reside in non-public Supabase Storage vaults (`id-documents`, `biometric-vault`). Direct public links are blocked.\n'
                      '• Time-Expiring Signed URLs: Inspectors review sensitive ID documents via HMAC-signed tokens with 300-second expiration.\n'
                      '• Mandatory Auto-Purge: Raw facial capture staging images are permanently deleted upon approval; only 512-d encrypted vector templates are retained.',
                      style: TextStyle(color: Color(0xFF166534), fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),
        ..._flaggedVerifications.map((item) {
          final isApproved = item['status'] == 'approved';
          final phone = item['phone_number'] as String? ?? '';
          final maskedPhone = _maskPhoneNumber(phone);

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isApproved ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                      child: Icon(
                        isApproved ? Icons.check_circle_rounded : Icons.pending_rounded,
                        color: isApproved ? const Color(0xFF059669) : const Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${item['name']} • ${item['role'].toString().toUpperCase()}',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item['idType'] ?? '',
                                  style: TextStyle(fontSize: 10.5, color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Masked Contact: $maskedPhone • Cosine Similarity: ${item['similarity']}% (Latency: ${item['latency']}s)',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isApproved ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item['status'].toString().toUpperCase(),
                        style: TextStyle(
                          color: isApproved ? const Color(0xFF059669) : const Color(0xFFB45309),
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item['note'] ?? '',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 11.5, fontStyle: FontStyle.italic),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            final mockToken = 'sign-hmac-${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Row(
                                  children: [
                                    Icon(Icons.vpn_key_rounded, color: Color(0xFF0284C7)),
                                    SizedBox(width: 8),
                                    Text('Time-Expiring Signed Document URL', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'RA 10173 Protected Access: This link expires in 300 seconds (5 minutes). Access is logged in biometric_access_logs.',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: SelectableText(
                                        'https://csqikuvfvfqfhhjptwcl.supabase.co/storage/v1/object/sign/id-documents/${item['id']}/license_scan.jpg?token=$mockToken&expires_in=300',
                                        style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace'),
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.key_rounded, size: 14),
                          label: const Text('Inspect ID (5m Signed Token)', style: TextStyle(fontSize: 11.5)),
                        ),
                        if (!isApproved)
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                item['status'] = 'approved';
                                item['note'] = 'Approved by MINC Admin. Raw staging images purged from private storage.';
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Verification for ${item['name']} approved. Raw staging images purged per NPC Circular 2023-03.'),
                                  backgroundColor: const Color(0xFF059669),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            icon: const Icon(Icons.verified_rounded, size: 14),
                            label: const Text('Approve & Purge Photos', style: TextStyle(fontSize: 11.5)),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ===========================================================================
  // 10. SETTINGS & REGULATORY COMPLIANCE VIEW
  // ===========================================================================
  Widget _buildSettingsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('System Settings & Regulatory Compliance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('City Ordinance 2023-005 parameters, statutory discount shares, and audit trail.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 18),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Statutory Discount Mandates', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              SizedBox(height: 14),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.school_rounded, color: Color(0xFF059669), size: 24),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Student Commuter Discount (20%)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          SizedBox(height: 2),
                          Text('Applies on base and succeeding km for enrolled college & high school students.', style: TextStyle(color: Colors.grey, fontSize: 11.5)),
                        ],
                      ),
                    ),
                    Text('Mandatory (RA 11314)', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w800, fontSize: 11)),
                  ],
                ),
              ),
              Divider(height: 16),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.elderly_rounded, color: Color(0xFF059669), size: 24),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Senior Citizen & PWD Discount (20%)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          SizedBox(height: 2),
                          Text('Applies upon presentation of OSCA or PWD card with 1:1 facial verification.', style: TextStyle(color: Colors.grey, fontSize: 11.5)),
                        ],
                      ),
                    ),
                    Text('Mandatory (RA 9994)', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w800, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Audit Trail Logs
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('System Audit Trail', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 12),
              ..._systemAuditLogs.map((log) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.history_rounded, size: 16, color: Colors.grey),
                      const SizedBox(width: 10),
                      Text(log['time'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      const SizedBox(width: 12),
                      Expanded(child: Text('${log['actor']}: ${log['action']}', style: const TextStyle(fontSize: 12))),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 11. FLEET & LIVE INCIDENT COMMAND SENTINEL VIEW
  // ===========================================================================
  Widget _buildLiveMonitoringView() {
    final activeAlerts = _sosAlerts.where((a) => a['status'] == 'ACTIVE_DISPATCHED').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Live Incident Command & Fleet Monitoring Sentinel', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text('Real-time SOS beacons, PostGIS GPS vehicle coordinates, and emergency PNP response.', style: TextStyle(color: Colors.grey)),
              ],
            ),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _simulateDriverSos,
                  icon: const Icon(Icons.emergency_rounded, color: Color(0xFFDC2626), size: 16),
                  label: const Text('Simulate Driver SOS', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _syncFromSupabase,
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: const Text('Refresh Telemetry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Live KPI Metrics Cards
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: activeAlerts.isNotEmpty ? const Color(0xFFFEF2F2) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: activeAlerts.isNotEmpty ? const Color(0xFFF87171) : Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('ACTIVE DISTRESS BEACONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: activeAlerts.isNotEmpty ? const Color(0xFF991B1B) : Colors.grey.shade600)),
                        Icon(Icons.emergency_rounded, color: activeAlerts.isNotEmpty ? const Color(0xFFDC2626) : Colors.grey.shade400, size: 18),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${activeAlerts.length}',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: activeAlerts.isNotEmpty ? const Color(0xFFDC2626) : const Color(0xFF0F172A)),
                    ),
                    Text(
                      activeAlerts.isNotEmpty ? 'Immediate response required' : 'All Laoag corridors normal',
                      style: TextStyle(fontSize: 11.5, color: activeAlerts.isNotEmpty ? const Color(0xFFB91C1C) : const Color(0xFF059669), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('ACTIVE TRICYCLES ON ROAD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade600)),
                        const Icon(Icons.two_wheeler_rounded, color: Color(0xFF059669), size: 18),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('89 Units', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                    const Text('Operating across 10 Laoag zones', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('LAOAG PNP STANDBY STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade600)),
                        const Icon(Icons.local_police_rounded, color: Color(0xFF2563EB), size: 18),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('ONLINE', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF2563EB))),
                    const Text('Hotline: (077) 772-0256 Ready', style: TextStyle(fontSize: 11.5, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Active Emergency SOS Beacons Card Table
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.emergency_rounded, color: Color(0xFFDC2626), size: 22),
                        SizedBox(width: 10),
                        Text('Live Driver Distress Beacons (Laoag City Command Sentinel)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: activeAlerts.isNotEmpty ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        activeAlerts.isNotEmpty ? '🚨 ${activeAlerts.length} ACTIVE INCIDENT' : '✓ 0 ACTIVE DISTRESS',
                        style: TextStyle(
                          color: activeAlerts.isNotEmpty ? const Color(0xFFDC2626) : const Color(0xFF059669),
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (_sosAlerts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text('No emergency SOS beacons recorded. All drivers operating safely.', style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                ..._sosAlerts.map((alert) {
                  final isActive = alert['status'] == 'ACTIVE_DISPATCHED';

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFFFFF7F7) : Colors.white,
                      border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isActive ? Icons.emergency_rounded : Icons.check_circle_rounded,
                            color: isActive ? const Color(0xFFDC2626) : const Color(0xFF059669),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('${alert['id']} • ${alert['driver_name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isActive ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      alert['status'],
                                      style: TextStyle(
                                        color: isActive ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Body ${alert['body_number']} • ${alert['plate_number']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text('Trigger: ${alert['alert_reason']} • ${alert['time_ago']}', style: const TextStyle(fontSize: 12)),
                              Text('GPS Coordinates: ${alert['latitude']}, ${alert['longitude']} (${alert['location_name']})', style: const TextStyle(fontFamily: 'Courier', fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            if (isActive) ...[
                              ElevatedButton.icon(
                                onPressed: () => _dispatchLaoagPnp(alert),
                                icon: const Icon(Icons.local_police_rounded, size: 15),
                                label: const Text('Dispatch PNP'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC2626),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () => _showSosIncidentModal(alert),
                                icon: const Icon(Icons.remove_red_eye_rounded, size: 15),
                                label: const Text('Inspect'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0F172A),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () => _resolveSosAlert(alert),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF059669),
                                  side: const BorderSide(color: Color(0xFFA7F3D0)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                child: const Text('Resolve'),
                              ),
                            ] else
                              TextButton.icon(
                                onPressed: () => _showSosIncidentModal(alert),
                                icon: const Icon(Icons.history_rounded, size: 16),
                                label: const Text('View Report'),
                                style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Live Queue Board Section
        _buildTodaQueueBoardView(),
      ],
    );
  }

  Widget _buildEmergencySosSentinelBanner() {
    final activeAlerts = _sosAlerts.where((a) => a['status'] == 'ACTIVE_DISPATCHED').toList();
    if (activeAlerts.isEmpty) return const SizedBox.shrink();

    final topAlert = activeAlerts.first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFEF2F2),
        border: Border(bottom: BorderSide(color: Color(0xFFF87171), width: 1.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFDC2626),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '🚨 ACTIVE EMERGENCY SOS (${activeAlerts.length})',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${topAlert['driver_name']} (${topAlert['body_number']})',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF991B1B)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• ${topAlert['location_name']}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Reason: ${topAlert['alert_reason']} • GPS: ${topAlert['latitude']}, ${topAlert['longitude']} • Triggered: ${topAlert['time_ago']}',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFFB91C1C)),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _showSosIncidentModal(topAlert),
            icon: const Icon(Icons.shield_rounded, size: 16),
            label: const Text('Inspect & Dispatch PNP'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => _resolveSosAlert(topAlert),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF991B1B),
              side: const BorderSide(color: Color(0xFFFCA5A5)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Resolve', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingDataExportTab() {
    return _buildMlSimulatorView();
  }

  // ===========================================================================
  // HELPER WIDGETS
  // ===========================================================================
  Widget _buildSidebarSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, top: 4.0, bottom: 8.0),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String title, {Widget? badge}) {
    final isSelected = _selectedSection == title;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: isSelected ? const Color(0xFFF1F5F9) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() {
              _selectedSection = title;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: isSelected ? const Color(0xFF059669) : Colors.grey.shade600,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF475569),
                    ),
                  ),
                ),
                if (badge != null) badge,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubTab(int index, String label) {
    final isSelected = _analyticsSubTab == index;

    return InkWell(
      onTap: () => setState(() => _analyticsSubTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF059669) : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? const Color(0xFF059669) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildKrispMetricCard({
    required String title,
    required String value,
    required String dateLabel,
    required String trendLabel,
    required bool trendPositive,
    required SparklineType sparklineType,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600,
                ),
              ),
              Icon(Icons.more_horiz_rounded, size: 18, color: Colors.grey.shade400),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                dateLabel,
                style: const TextStyle(fontSize: 10.5, color: Colors.grey),
              ),
              const SizedBox(width: 8),
              Text(
                trendLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: trendPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            height: 38,
            width: double.infinity,
            child: CustomPaint(
              painter: _SparklinePainter(type: sparklineType),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildMlMetricBadge(String title, String val, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(val, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade600, fontSize: 10)),
        ],
      ),
    );
  }
}

// =============================================================================
// MAP PAINTER: LAOAG 10-ZONE ROAD & RIVER NETWORK
// =============================================================================
class _LaoagMapPainter extends CustomPainter {
  final List<Map<String, dynamic>> zones;
  final String selectedCode;
  final double Function(Map<String, dynamic>) getDemand;

  _LaoagMapPainter({
    required this.zones,
    required this.selectedCode,
    required this.getDemand,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Padsan River (blue curve)
    final riverPaint = Paint()
      ..color = const Color(0xFFBAE6FD)
      ..strokeWidth = 24
      ..style = PaintingStyle.stroke;

    final riverPath = Path()
      ..moveTo(0, size.height * 0.72)
      ..cubicTo(
        size.width * 0.35,
        size.height * 0.65,
        size.width * 0.65,
        size.height * 0.58,
        size.width,
        size.height * 0.60,
      );
    canvas.drawPath(riverPath, riverPaint);

    // 2. Draw Gilbert Bridge (Crossing Padsan River to San Nicolas)
    final bridgePaint = Paint()
      ..color = const Color(0xFF64748B)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width * 0.44, size.height * 0.58),
      Offset(size.width * 0.47, size.height * 0.68),
      bridgePaint,
    );

    // 3. Draw Road Arterials (J.P. Rizal St., Gen. Luna, Airport Rd.)
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    // J.P. Rizal Street (East-West spine)
    canvas.drawLine(Offset(0, size.height * 0.44), Offset(size.width, size.height * 0.44), roadPaint);
    // Gen. Antonio Luna St. (North-South spine)
    canvas.drawLine(Offset(size.width * 0.50, 0), Offset(size.width * 0.50, size.height), roadPaint);
    // Airport Road (Diagonal to Gabu West)
    canvas.drawLine(Offset(size.width * 0.44, size.height * 0.44), Offset(0, size.height * 0.75), roadPaint);

    // 4. Draw Zones Geofence Glows
    for (final z in zones) {
      final demand = getDemand(z);
      final px = (z['x'] as double) * size.width;
      final py = (z['y'] as double) * size.height;
      final isSelected = z['code'] == selectedCode;

      Color haloColor = const Color(0xFF10B981);
      if (demand >= 25) {
        haloColor = const Color(0xFFEF4444);
      } else if (demand >= 15) {
        haloColor = const Color(0xFFF59E0B);
      } else if (demand < 5) {
        haloColor = const Color(0xFF94A3B8);
      }

      final glowPaint = Paint()
        ..color = haloColor.withValues(alpha: isSelected ? 0.35 : 0.15)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(px, py), isSelected ? 42 : 32, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LaoagMapPainter oldDelegate) => true;
}

// =============================================================================
// KRISP TREND CHART PAINTER
// =============================================================================
class _KrispTrendChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double leftMargin = 55.0;
    const double bottomMargin = 28.0;
    const double topMargin = 16.0;

    final double chartWidth = size.width - leftMargin;
    final double chartHeight = size.height - bottomMargin - topMargin;

    final gridPaint = Paint()
      ..color = Colors.grey.shade100
      ..strokeWidth = 1.0;

    const textStyle = TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w600);
    final levels = [100.0, 80.0, 60.0, 40.0, 20.0, 0.0];

    for (final level in levels) {
      final y = topMargin + chartHeight * (1.0 - (level / 100.0));
      canvas.drawLine(Offset(leftMargin, y), Offset(size.width, y), gridPaint);

      final textSpan = TextSpan(text: '${level.toInt()}.00%', style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      textPainter.paint(canvas, Offset(leftMargin - textPainter.width - 8, y - 6));
    }

    final weeks = ['Wk 1', 'Wk 2', 'Wk 3', 'Wk 4', 'Wk 5', 'Wk 6', 'Wk 7', 'Wk 8'];
    final double stepX = chartWidth / (weeks.length - 1);

    for (int i = 0; i < weeks.length; i++) {
      final x = leftMargin + (i * stepX);
      final textSpan = TextSpan(text: weeks[i], style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      textPainter.paint(canvas, Offset(x - (textPainter.width / 2), size.height - bottomMargin + 8));
    }

    final adoptionData = [10.0, 18.5, 34.0, 52.0, 68.0, 78.5, 84.0, 88.5];
    final deploymentData = [0.0, 2.5, 4.0, 6.0, 8.5, 10.0, 11.0, 11.11];

    _drawSmoothCurve(canvas, adoptionData, chartWidth, chartHeight, leftMargin, topMargin, const Color(0xFF3B82F6), true);
    _drawSmoothCurve(canvas, deploymentData, chartWidth, chartHeight, leftMargin, topMargin, const Color(0xFFF97316), false);
  }

  void _drawSmoothCurve(Canvas canvas, List<double> data, double width, double height, double left, double top, Color color, bool fillArea) {
    final double stepX = width / (data.length - 1);
    final points = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final x = left + (i * stepX);
      final y = top + height * (1.0 - (data[i] / 100.0));
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    if (fillArea) {
      final fillPath = Path.from(path)
        ..lineTo(points.last.dx, top + height)
        ..lineTo(points.first.dx, top + height)
        ..close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(left, top, width, height));

      canvas.drawPath(fillPath, fillPaint);
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = color;
    final whitePaint = Paint()..color = Colors.white;

    for (final pt in points) {
      canvas.drawCircle(pt, 4.0, dotPaint);
      canvas.drawCircle(pt, 2.0, whitePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =============================================================================
// SPARKLINE PAINTER FOR KPI METRIC CARDS
// =============================================================================
enum SparklineType { upwardSmooth, steadyRise, downwardEfficiency, mildRise }

class _SparklinePainter extends CustomPainter {
  final SparklineType type;
  _SparklinePainter({required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    List<double> normalizedPoints;
    Color strokeColor;

    switch (type) {
      case SparklineType.upwardSmooth:
        normalizedPoints = [0.2, 0.25, 0.35, 0.55, 0.70, 0.95];
        strokeColor = const Color(0xFF3B82F6);
        break;
      case SparklineType.steadyRise:
        normalizedPoints = [0.1, 0.15, 0.40, 0.50, 0.75, 0.90];
        strokeColor = const Color(0xFF3B82F6);
        break;
      case SparklineType.downwardEfficiency:
        normalizedPoints = [0.85, 0.80, 0.65, 0.40, 0.30, 0.20];
        strokeColor = const Color(0xFF10B981);
        break;
      case SparklineType.mildRise:
        normalizedPoints = [0.15, 0.22, 0.38, 0.50, 0.65, 0.72];
        strokeColor = const Color(0xFF3B82F6);
        break;
    }

    final double stepX = size.width / (normalizedPoints.length - 1);
    final points = <Offset>[];

    for (int i = 0; i < normalizedPoints.length; i++) {
      final x = i * stepX;
      final y = size.height * (1.0 - normalizedPoints[i]);
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [strokeColor.withValues(alpha: 0.25), strokeColor.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = strokeColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
