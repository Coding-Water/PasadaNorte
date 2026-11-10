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

    testWidgets('Ratings 1 and 2 require feedback before submission, but allow skipping', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createLiveRideTrackingScreen());
      // Skip radar & approach to reach headingToDestination
      await tester.pump(const Duration(seconds: 12));

      // Tap "Arrive Now ➔" to immediately enter arrivedAtDestination phase
      expect(find.text('Arrive Now ➔'), findsOneWidget);
      await tester.tap(find.text('Arrive Now ➔'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('You have arrived!'), findsOneWidget);
      expect(find.text('How was your mood during this trip?'), findsOneWidget);

      // Default rating is mood 4 (Happy) -> feedback is NOT required, "Finish" button is displayed
      expect(find.text('Finish'), findsOneWidget);
      expect(find.text('Submit Feedback'), findsNothing);

      // Tap Mood 1 (very unhappy face - index 0)
      await tester.tap(find.byKey(const ValueKey('mood_face_0')));
      await tester.pump(const Duration(milliseconds: 300));

      // Feedback section is now visible
      expect(find.textContaining('Why was your rating 1 of 5?'), findsOneWidget);
      expect(find.text('Submit Feedback'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      // 1. Tapping "Submit Feedback" without selecting reason or typing details triggers required validation
      await tester.ensureVisible(find.text('Submit Feedback'));
      await tester.tap(find.text('Submit Feedback'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Please select a reason, type details, or tap Skip'), findsOneWidget);

      // 2. Select a reason chip
      expect(find.text('Overcharging (Ord. 2023-005)'), findsOneWidget);
      await tester.ensureVisible(find.text('Overcharging (Ord. 2023-005)'));
      await tester.tap(find.text('Overcharging (Ord. 2023-005)'));
      await tester.pump(const Duration(milliseconds: 300));

      // Submit feedback now succeeds and completes trip
      await tester.ensureVisible(find.text('Submit Feedback'));
      await tester.tap(find.text('Submit Feedback'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Thanks for your feedback!'), findsOneWidget);
    });

    testWidgets('Ratings 1 and 2 can be skipped without providing feedback', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createLiveRideTrackingScreen());
      await tester.pump(const Duration(seconds: 12));

      await tester.tap(find.text('Arrive Now ➔'));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Mood 2 (slight frown - index 1)
      await tester.tap(find.byKey(const ValueKey('mood_face_1')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Why was your rating 2 of 5?'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      // Passenger decides to skip feedback
      await tester.ensureVisible(find.text('Skip'));
      await tester.tap(find.text('Skip'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Trip successfully finishes without requiring feedback
      expect(find.text('Thanks for your feedback!'), findsOneWidget);
    });

    testWidgets('Tapping Finish for standard mood completes trip directly without duplicate rate screen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createLiveRideTrackingScreen());
      await tester.pump(const Duration(seconds: 12));

      await tester.tap(find.text('Arrive Now ➔'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Finish'), findsOneWidget);
      await tester.ensureVisible(find.text('Finish'));
      await tester.tap(find.text('Finish'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Reaches Thanks for your feedback directly; obsolete "How was the driver?" screen is NOT shown
      expect(find.text('Thanks for your feedback!'), findsOneWidget);
      expect(find.text('How was the driver?'), findsNothing);
    });
  });
}
