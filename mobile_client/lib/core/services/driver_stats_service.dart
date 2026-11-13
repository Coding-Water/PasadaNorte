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

  // In-memory stats initialized to zero for clean real-user accounts
  static double todayTotalEarnings = 0.00;
  static int todayCompletedTrips = 0;
  static double todayHoursOnline = 0.0;
  static double cashEarnings = 0.00;
  static double gcashEarnings = 0.00;

  static final List<CompletedTripRecord> recentTrips = [];

  // Driver & Tricycle Franchise Profile (populated per logged-in / registered driver)
  static String driverFullName = 'Driver';
  static String todaAssociation = 'No Assigned TODA Yet';
  static String bodyNumber = 'Pending';
  static String plateNumber = 'Unassigned';
  static String mincFranchiseNumber = 'Pending MINC Approval';
  static String franchiseExpiry = 'Pending';
  static bool isFranchiseActive = false;
  static String ltoRegistrationExpiry = 'Pending';
  static String lastInspectionStatus = 'Pending MINC Review';

  static void setActiveDriverProfile({
    required String fullName,
    String? plateNo,
    String? todaName,
    String? bodyNo,
  }) {
    driverFullName = fullName.trim().isNotEmpty ? fullName.trim() : 'Driver';
    if (plateNo != null && plateNo.trim().isNotEmpty) {
      plateNumber = plateNo.trim();
    }
    if (todaName != null && todaName.trim().isNotEmpty) {
      todaAssociation = todaName.trim();
    }
    if (bodyNo != null && bodyNo.trim().isNotEmpty) {
      bodyNumber = bodyNo.trim();
    }
  }

  static Future<void> resetForNewDriver({
    required String fullName,
    String? plateNo,
  }) async {
    todayTotalEarnings = 0.00;
    todayCompletedTrips = 0;
    todayHoursOnline = 0.0;
    cashEarnings = 0.00;
    gcashEarnings = 0.00;
    recentTrips.clear();
    driverFullName = fullName.trim().isNotEmpty ? fullName.trim() : 'Driver';
    todaAssociation = 'No Assigned TODA Yet';
    bodyNumber = 'Pending';
    plateNumber = (plateNo != null && plateNo.trim().isNotEmpty)
        ? plateNo.trim()
        : 'Pending';
    mincFranchiseNumber = 'Pending MINC Approval';
    franchiseExpiry = 'Pending';
    isFranchiseActive = false;
    ltoRegistrationExpiry = 'Pending';
    lastInspectionStatus = 'Pending MINC Review';
    // Clear persisted stats in the background without blocking navigation
    Future<void>(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_kEarningsKey);
        await prefs.remove(_kTripsCountKey);
        await prefs.remove(_kHoursOnlineKey);
      } catch (_) {}
    });
  }

  static Future<void> loadSavedStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      todayTotalEarnings = prefs.getDouble(_kEarningsKey) ?? 0.00;
      todayCompletedTrips = prefs.getInt(_kTripsCountKey) ?? 0;
      todayHoursOnline = prefs.getDouble(_kHoursOnlineKey) ?? 0.0;
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
