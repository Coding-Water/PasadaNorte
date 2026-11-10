import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_client/features/driver/views/driver_active_trip_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createActiveTripScreen() {
    return const MaterialApp(
      home: DriverActiveTripScreen(
        driverName: 'Juan Dela Cruz',
        passengerName: 'Maria Clara Santos',
      ),
    );
  }

  group('DriverActiveTripScreen - Minimalist HUD & Expandable Bottom Sheet Tests', () {
    testWidgets('Initial view shows Image 1 with Call, Chat, Upfront Fare, and Image 6 GPS button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createActiveTripScreen());
      await tester.pump();

      // 1. Initial State has Image 1 (Full expanded sheet)
      expect(find.text('Maria Clara Santos'), findsOneWidget);
      expect(find.text('PILA RANK #1'), findsOneWidget);
      expect(find.textContaining('Calculated Upfront Fare'), findsOneWidget);

      // Call and Chat buttons must be present before pickup
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.phone_outlined), findsOneWidget);

      // 2. Image 6 GPS FAB is present
      expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);

      // 3. Removed clutter: Detour button and Image 4/5 banners are absent
      expect(find.text('AUTO-FOLLOW: ACTIVE • HANDS-FREE SAFETY'), findsNothing);
      expect(find.textContaining('MAP MOVED • TAP TO RESUME AUTO-FOLLOW'), findsNothing);
      expect(find.byIcon(Icons.alt_route_rounded), findsNothing);
    });

    testWidgets('Swiping down collapses sheet to only Image 2 (profile) and Image 3 (slider)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createActiveTripScreen());
      await tester.pump();

      // Ensure fare card is initially visible
      expect(find.textContaining('Calculated Upfront Fare'), findsOneWidget);

      // Swipe down on the bottom sheet
      await tester.drag(find.text('Maria Clara Santos'), const Offset(0, 300));
      await tester.pumpAndSettle();

      // Collapsed: Fare card is hidden, passenger profile and slider remain visible
      expect(find.textContaining('Calculated Upfront Fare'), findsNothing);
      expect(find.text('Maria Clara Santos'), findsOneWidget);
      expect(find.textContaining('SLIDE'), findsOneWidget);

      // Swipe up to re-expand
      await tester.drag(find.text('Maria Clara Santos'), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Expanded: Fare card is visible again
      expect(find.textContaining('Calculated Upfront Fare'), findsOneWidget);
    });

    testWidgets('Call and Chat buttons disappear when passenger is picked up (in transit to dropoff)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createActiveTripScreen());
      await tester.pump();

      // Initially before pickup: Call & Chat are present
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.phone_outlined), findsOneWidget);

      // Slide to arrive at pickup
      await tester.drag(find.byType(GestureDetector).last, const Offset(300, 0));
      await tester.pumpAndSettle();

      // Still at pickup waiting: Call & Chat are present
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.phone_outlined), findsOneWidget);

      // Slide to start trip (Passenger boards vehicle)
      await tester.drag(find.byType(GestureDetector).last, const Offset(300, 0));
      await tester.pumpAndSettle();

      // In transit: Call & Chat DISAPPEAR to maximize screen space for driving
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsNothing);
      expect(find.byIcon(Icons.phone_outlined), findsNothing);
    });
  });
}
