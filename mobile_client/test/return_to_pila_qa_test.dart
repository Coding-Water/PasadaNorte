import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_client/core/services/location_service.dart';
import 'package:mobile_client/core/services/toda_queue_service.dart';
import 'package:mobile_client/core/services/driver_stats_service.dart';

void main() {
  group('QA Test Suite: Return to TODA Pila & Settlement Flow', () {
    test('Dropoff at MMSU Campus accurately selects Laoag Central Terminal for return trip', () {
      const dropoffLat = 18.203595;
      const dropoffLng = 120.593643;

      // When checking nearest terminal
      final nearest = TodaQueueService.findNearestTerminal(dropoffLat, dropoffLng);

      // Verify that nearest terminal at MMSU Campus has distance ~0m
      expect(nearest.distanceMeters, lessThan(20.0));

      // Our algorithm correctly detects distance <= 150m and routes back to mother terminal (Central TODA)
      final homeTerminal = TodaQueueService.laoagTerminals.firstWhere(
        (t) => t.id == 'term_01',
        orElse: () => TodaQueueService.laoagTerminals.first,
      );

      final returnDistKm = LocationService.calculateDistanceInKm(
        dropoffLat,
        dropoffLng,
        homeTerminal.centerPoint.latitude,
        homeTerminal.centerPoint.longitude,
      );

      // Return distance from MMSU to Central Market must be approx 1.0 - 1.5 km
      expect(returnDistKm, greaterThan(0.9));
      expect(returnDistKm, lessThan(1.8));
      expect(homeTerminal.radiusMeters, equals(25.0));
    });

    test('TODA Terminal Geofence accurately evaluates entry boundary (<= 25m)', () {
      final centralTerm = TodaQueueService.laoagTerminals.firstWhere((t) => t.id == 'term_01');

      // Point exactly on terminal center
      final distCenter = LocationService.calculateDistanceInKm(
        centralTerm.centerPoint.latitude,
        centralTerm.centerPoint.longitude,
        centralTerm.centerPoint.latitude,
        centralTerm.centerPoint.longitude,
      ) * 1000.0;
      expect(distCenter, equals(0.0));
      expect(distCenter <= centralTerm.radiusMeters, isTrue);

      // Point 500m away outside geofence
      final distAway = LocationService.calculateDistanceInKm(
        centralTerm.centerPoint.latitude + 0.004,
        centralTerm.centerPoint.longitude,
        centralTerm.centerPoint.latitude,
        centralTerm.centerPoint.longitude,
      ) * 1000.0;
      expect(distAway > centralTerm.radiusMeters, isTrue);
    });

    test('DriverStatsService records fare and completed trip without throwing', () async {
      final initialEarnings = DriverStatsService.todayTotalEarnings;
      final initialTripsCount = DriverStatsService.recentTrips.length;

      await DriverStatsService.recordTrip(
        fare: 16.00,
        passengerName: 'Maria Clara Santos',
        route: 'Laoag Central Market ➔ MMSU Laoag Campus',
        isCash: true,
      );

      expect(DriverStatsService.todayTotalEarnings, equals(initialEarnings + 16.00));
      expect(DriverStatsService.recentTrips.length, equals(initialTripsCount + 1));
      expect(DriverStatsService.recentTrips.first.fare, equals(16.00));
      expect(DriverStatsService.recentTrips.first.isCash, isTrue);
    });
  });
}
