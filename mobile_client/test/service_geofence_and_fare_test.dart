import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_client/core/services/location_service.dart';
import 'package:mobile_client/features/fare/services/fare_calculator_service.dart';

void main() {
  group('LocationService Hard Geofence', () {
    test('allows Laoag City and Ilocos Norte municipalities', () {
      // Laoag City Plaza
      expect(LocationService.isWithinServiceArea(18.1965, 120.5938), isTrue);
      // Robinsons San Nicolas
      expect(LocationService.isWithinServiceArea(18.1845, 120.5912), isTrue);
      // Batac City
      expect(LocationService.isWithinServiceArea(18.0556, 120.5639), isTrue);
      // Paoay
      expect(LocationService.isWithinServiceArea(18.0614, 120.5217), isTrue);
      // Bangui
      expect(LocationService.isWithinServiceArea(18.5378, 120.7667), isTrue);
      // Pagudpud
      expect(LocationService.isWithinServiceArea(18.5614, 120.7931), isTrue);
    });

    test('blocks Hong Kong, Manila, and Vigan (Ilocos Sur)', () {
      // Hong Kong
      expect(LocationService.isWithinServiceArea(22.3193, 114.1694), isFalse);
      // Metro Manila
      expect(LocationService.isWithinServiceArea(14.5995, 120.9842), isFalse);
      // Vigan City (Ilocos Sur)
      expect(LocationService.isWithinServiceArea(17.5747, 120.3869), isFalse);
    });
  });

  group('FareCalculatorService Two-Tier Pricing', () {
    test('keeps Laoag City Ordinance rate for intra-city trips <= 8 km', () {
      final breakdown = FareCalculatorService.calculateFare(
        distanceKm: 5.0,
        category: PassengerCategory.regular,
      );
      expect(breakdown.isInterMunicipality, isFalse);
      expect(breakdown.finalFare, 28.00); // 20 + (4 * 2)
    });

    test('applies inter-municipality rate for trips > 8 km', () {
      final batacTrip = FareCalculatorService.calculateFare(
        distanceKm: 20.0,
        category: PassengerCategory.regular,
      );
      expect(batacTrip.isInterMunicipality, isTrue);
      // 20 + (7 * 2) + (12 * 15) = 214.00
      expect(batacTrip.finalFare, 214.00);

      final pagudpudTrip = FareCalculatorService.calculateFare(
        distanceKm: 72.0,
        category: PassengerCategory.regular,
      );
      expect(pagudpudTrip.isInterMunicipality, isTrue);
      // 20 + (7 * 2) + (64 * 15) = 994.00
      expect(pagudpudTrip.finalFare, 994.00);
    });
  });
}
