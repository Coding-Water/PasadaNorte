import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_client/core/services/location_service.dart';
import 'package:mobile_client/features/fare/services/fare_calculator_service.dart';
import 'package:mobile_client/features/rider/views/live_ride_tracking_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createLiveRideTrackingScreen() {
    return MaterialApp(
      home: LiveRideTrackingScreen(
        passengerName: 'Maria Clara Santos',
        pickupPoint: const LocationPoint(
          latitude: 18.194096,
          longitude: 120.595856,
          name: 'Laoag Public Market',
        ),
        dropoffPoint: const LocationPoint(
          latitude: 18.203595,
          longitude: 120.593643,
          name: 'MMSU Laoag Campus',
        ),
        routePolyline: const [
          LatLng(18.194096, 120.595856),
          LatLng(18.203595, 120.593643),
        ],
        fareBreakdown: FareCalculatorService.calculateFare(
          distanceKm: 1.25,
          category: PassengerCategory.student,
        ),
        paymentMethod: 'CASH TO COLLECT',
      ),
    );
  }

  group('LiveRideTrackingScreen - Call & Chat Visibility by Phase', () {
    testWidgets('Call and Chat are present during approach, then removed when driver picks up passenger', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createLiveRideTrackingScreen());
      // Initial phase: findingDriver (3 second radar timer)
      await tester.pump(const Duration(milliseconds: 500));

      // Fast-forward 3.5 seconds to trigger driverHeadingToPickup phase
      await tester.pump(const Duration(seconds: 4));

      // Phase 1 (Driver Heading to Pickup): Call and Chat buttons must be present
      expect(find.text('Driver is heading to your location...'), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.phone_outlined), findsWidgets); // One in text row, one in action button

      // Fast-forward to finish approach and trigger pickup -> headingToDestination phase
      await tester.pump(const Duration(seconds: 8));

      // Phase 2 (Heading to destination): Driver has picked up passenger
      expect(find.text('Heading to destination...'), findsOneWidget);

      // Call and Chat action buttons must be REMOVED since passenger is already on board
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsNothing);
    });
  });
}
