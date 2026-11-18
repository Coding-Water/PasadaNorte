import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_client/core/services/location_service.dart';
import 'package:mobile_client/core/services/supabase_service.dart';
import 'package:mobile_client/features/driver/views/driver_active_trip_screen.dart';
import 'package:mobile_client/features/fare/services/fare_calculator_service.dart';
import 'package:mobile_client/features/rider/models/activity_trip_model.dart';
import 'package:mobile_client/features/rider/views/live_ride_tracking_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SupabaseService.tripChatNotifier.value = [];
    SupabaseService.debugForceOnlineForCall = null;
    SupabaseService.lastLaunchedTelUri = null;
  });

  tearDown(() {
    SupabaseService.debugForceOnlineForCall = null;
  });

  Widget createDriverScreen() {
    return const MaterialApp(
      home: DriverActiveTripScreen(
        driverName: 'Juan Dela Cruz',
        passengerName: 'Maria Clara Santos',
      ),
    );
  }

  Widget createPassengerScreen() {
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
        autoAcceptForTesting: true,
      ),
    );
  }

  group('Real-Time Chat & Wi-Fi/Data Call + Offline Phone Fallback Tests', () {
    testWidgets('Driver Chat sends quick reply and syncs incoming passenger messages via SupabaseService', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createDriverScreen());
      await tester.pump();

      // Open Driver Chat Modal
      await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('In-Trip Passenger Chat'), findsOneWidget);

      // Tap quick reply 'Dadditoyakon!'
      await tester.tap(find.text('Dadditoyakon!'));
      await tester.pump();

      expect(
        find.text('Dadditoyakon dita pickup terminal! (I am here!)'),
        findsOneWidget,
      );

      // Simulate Passenger sending a message over Realtime
      await SupabaseService.sendTripChatMessage(
        senderRole: 'passenger',
        senderName: 'Maria Clara Santos',
        text: 'Kita na po kita manong!',
      );
      await tester.pump();

      expect(find.text('Kita na po kita manong!'), findsOneWidget);
    });

    testWidgets('Driver Call uses Wi-Fi/Data Call first when online, and falls back to mobile phone call only when offline', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createDriverScreen());
      await tester.pump();

      // 1. Online (Wi-Fi / Data available) -> Opens Wi-Fi / Data Call sheet
      SupabaseService.debugForceOnlineForCall = true;
      await tester.tap(find.byIcon(Icons.phone_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Voice Call'));
      await tester.pumpAndSettle();

      expect(find.text('Wi-Fi / Data Call'), findsOneWidget);
      expect(find.textContaining('Connected via Wi-Fi / Data'), findsOneWidget);

      // End the Wi-Fi call
      await tester.tap(find.text('End Call'));
      await tester.pumpAndSettle();

      // 2. Offline (No Wi-Fi or Data) -> Falls back to mobile phone dialer (tel:)
      SupabaseService.debugForceOnlineForCall = false;
      await tester.tap(find.byIcon(Icons.phone_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Voice Call'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(SupabaseService.lastLaunchedTelUri, 'tel:+639178492038');
      expect(
        find.text('No Wi-Fi/Data: Switching to mobile phone call...'),
        findsOneWidget,
      );
    });

    testWidgets('Passenger Call uses Wi-Fi/Data Call first when online, and falls back to mobile phone call only when offline', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createPassengerScreen());
      await tester.pump(const Duration(milliseconds: 500));
      // Advance 3.5 seconds past findingDriver radar to driverHeadingToPickup phase
      await tester.pump(const Duration(milliseconds: 3500));
      // Advance 3.2 seconds so the _showRiderAcceptedPrompt overlay auto-dismisses
      await tester.pump(const Duration(milliseconds: 3200));
      await tester.pump();

      // 1. Offline -> Falls back to mobile phone call (tel:)
      SupabaseService.debugForceOnlineForCall = false;
      final callBtnInkWell = tester.widget<InkWell>(
        find.descendant(
          of: find.byTooltip('Call Driver'),
          matching: find.byType(InkWell),
        ),
      );
      callBtnInkWell.onTap!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(SupabaseService.lastLaunchedTelUri, 'tel:+639178402291');
      expect(
        find.text('No Wi-Fi/Data: Switching to mobile phone call...'),
        findsOneWidget,
      );

      // 2. Online -> Opens Wi-Fi / Data Call screen
      SupabaseService.debugForceOnlineForCall = true;
      callBtnInkWell.onTap!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Wi-Fi / Data Call'), findsOneWidget);
    });

    testWidgets('Live Trip Stage Sync updates Passenger screen and records completed trip into ActivityRepository', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final initialCompletedCount = ActivityRepository.getCompleted().length;

      await tester.pumpWidget(createPassengerScreen());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 3500));
      await tester.pump(const Duration(milliseconds: 3200));

      // Driver broadcasts inTransitToDropoff
      SupabaseService.broadcastTripStageUpdate(stage: 'inTransitToDropoff');
      await tester.pump();
      while (tester.takeException() != null) {}
      expect(find.text('Heading to destination...'), findsOneWidget);

      // Driver broadcasts tripCompleted
      SupabaseService.broadcastTripStageUpdate(stage: 'tripCompleted');
      await tester.pump();
      while (tester.takeException() != null) {}

      expect(
        ActivityRepository.getCompleted().length,
        initialCompletedCount + 1,
      );
      expect(
        ActivityRepository.getCompleted().first.title,
        'MMSU Laoag Campus',
      );
    });
  });
}
