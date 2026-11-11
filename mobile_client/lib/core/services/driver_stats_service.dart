import 'package:shared_preferences/shared_preferences.dart';

class CompletedTripRecord {
  final String id;
  final String passengerName;
  final String route;
  final double fare;
  final bool isCash;
  final DateTime timestamp;

  const CompletedTripRecord({
    required this.id,
    required this.passengerName,
    required this.route,
    required this.fare,
    required this.isCash,
    required this.timestamp,
  });
}

class DriverStatsService {
  static const String _kEarningsKey = 'pn_driver_today_earnings';
  static const String _kTripsCountKey = 'pn_driver_today_trips';
  static const String _kHoursOnlineKey = 'pn_driver_today_hours';

  // In-memory stats initialized with realistic daily baseline
  static double todayTotalEarnings = 385.00;
  static int todayCompletedTrips = 14;
  static double todayHoursOnline = 4.5;
  static double cashEarnings = 325.00;
  static double gcashEarnings = 60.00;

  static final List<CompletedTripRecord> recentTrips = [
    CompletedTripRecord(
      id: 'TRIP-104',
      passengerName: 'Maria Clara Santos',
      route: 'Laoag Central Market ➔ MMSU Gate 2',
      fare: 15.00,
      isCash: true,
      timestamp: DateTime.now().subtract(const Duration(minutes: 18)),
    ),
    CompletedTripRecord(
      id: 'TRIP-103',
      passengerName: 'Engr. Juan Reyes',
      route: 'Plaza Salcedo ➔ Robinsons Ilocos',
      fare: 25.00,
      isCash: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 54)),
    ),
    CompletedTripRecord(
      id: 'TRIP-102',
      passengerName: 'Aling Remedios',
      route: 'LCGH Hospital ➔ Brgy. 2 Santa Joaquina',
      fare: 20.00,
      isCash: true,
      timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 25)),
    ),
    CompletedTripRecord(
      id: 'TRIP-101',
      passengerName: 'Mark Angelo Castro',
      route: 'INCAT School ➔ Gilbert Bridge South',
      fare: 20.00,
      isCash: true,
      timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: 10)),
    ),
  ];

  // Driver & Tricycle Franchise Profile
  static const String driverFullName = 'Eduardo "Manong Eddie" Castro';
  static const String todaAssociation = 'Laoag Central Terminal TODA Association';
  static const String bodyNumber = '0042';
  static const String plateNumber = '7489-IN';
  static const String mincFranchiseNumber = 'MINC-LAOAG-2024-0892';
  static const String franchiseExpiry = 'December 31, 2027';
  static const bool isFranchiseActive = true;
  static const String ltoRegistrationExpiry = 'October 24, 2027';
  static const String lastInspectionStatus = 'Laoag LGU Inspection • Passed';

  static Future<void> loadSavedStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      todayTotalEarnings = prefs.getDouble(_kEarningsKey) ?? 385.00;
      todayCompletedTrips = prefs.getInt(_kTripsCountKey) ?? 14;
      todayHoursOnline = prefs.getDouble(_kHoursOnlineKey) ?? 4.5;
    } catch (_) {}
  }

  static Future<void> recordTrip({
    required double fare,
    required String passengerName,
    required String route,
    bool isCash = true,
  }) async {
    todayTotalEarnings += fare;
    todayCompletedTrips += 1;
    if (isCash) {
      cashEarnings += fare;
    } else {
      gcashEarnings += fare;
    }

    recentTrips.insert(
      0,
      CompletedTripRecord(
        id: 'TRIP-${100 + todayCompletedTrips}',
        passengerName: passengerName,
        route: route,
        fare: fare,
        isCash: isCash,
        timestamp: DateTime.now(),
      ),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kEarningsKey, todayTotalEarnings);
      await prefs.setInt(_kTripsCountKey, todayCompletedTrips);
    } catch (_) {}
  }
}
