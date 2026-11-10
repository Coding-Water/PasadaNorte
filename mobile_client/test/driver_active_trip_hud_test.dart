import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_client/features/driver/views/driver_active_trip_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createActiveTripScreen({bool initialSheetExpanded = false}) {
    return MaterialApp(
      home: DriverActiveTripScreen(
        driverName: 'Juan Dela Cruz',
        passengerName: 'Maria Clara Santos',
        initialSheetExpanded: initialSheetExpanded,
      ),
    );
  }

  group('DriverActiveTripScreen - Minimalist HUD & Expandable Bottom Sheet Tests', () {
    testWidgets('Initial view starts slid down first (Image 2 profile + Image 3 slider, no fare card)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createActiveTripScreen());
      await tester.pump();

      // 1. Slid down first: Fare breakdown is hidden, passenger profile and slider are visible
      expect(find.textContaining('Calculated Upfront Fare'), findsNothing);
      expect(find.text('Maria Clara Santos'), findsOneWidget);
      expect(find.textContaining('SLIDE WHEN ARRIVED AT PICKUP'), findsOneWidget);

      // Call and Chat buttons must be present before pickup
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.phone_outlined), findsOneWidget);

      // 2. Image 6 GPS FAB is present on bottom right
      expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);

      // 3. Removed clutter: Detour button and Image 4/5 banners are absent
      expect(find.text('AUTO-FOLLOW: ACTIVE • HANDS-FREE SAFETY'), findsNothing);
      expect(find.textContaining('MAP MOVED • TAP TO RESUME AUTO-FOLLOW'), findsNothing);
      expect(find.byIcon(Icons.alt_route_rounded), findsNothing);
    });

    testWidgets('Swiping up expands sheet to Image 1 (full fare details), swiping down collapses it', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createActiveTripScreen());
      await tester.pump();

      // Initially slid down: fare card is hidden
      expect(find.textContaining('Calculated Upfront Fare'), findsNothing);

      // Swipe UP on the bottom sheet to expand
      await tester.drag(find.text('Maria Clara Santos'), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Expanded: Header, Rank pill, and Upfront Fare card are visible
      expect(find.textContaining('Calculated Upfront Fare'), findsOneWidget);
      expect(find.text('PILA RANK #1'), findsOneWidget);
      expect(find.text('Maria Clara Santos'), findsOneWidget);

      // Swipe DOWN to collapse again
      await tester.drag(find.text('Maria Clara Santos'), const Offset(0, 300));
      await tester.pumpAndSettle();

      // Collapsed: Fare card is hidden again
      expect(find.textContaining('Calculated Upfront Fare'), findsNothing);
      expect(find.text('Maria Clara Santos'), findsOneWidget);
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

      // At pickup waiting: Call & Chat are still present
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
