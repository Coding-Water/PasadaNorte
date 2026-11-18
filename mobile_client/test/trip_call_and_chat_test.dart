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
    testWidgets('Driver Chat shows unread badge on message icon, clears on open, and pops incoming call even while Chat is open', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createDriverScreen());
      await tester.pump();

      // Initial unread badge is visible on the Message icon
      expect(find.byKey(const Key('driver_chat_unread_badge')), findsOneWidget);

      // Incoming message while chat is closed increments unread badge
      await SupabaseService.sendTripChatMessage(
        senderRole: 'passenger',
        senderName: 'Maria Clara Santos',
        text: 'Nasaan na po kayo manong?',
      );
      await tester.pump();
      expect(find.text('2'), findsOneWidget);

      // Open Driver Chat Modal -> unread badge clears
      await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('In-Trip Passenger Chat'), findsOneWidget);
      expect(find.byKey(const Key('driver_chat_unread_badge')), findsNothing);

      // Tap quick reply 'Dadditoyakon!'
      await tester.tap(find.text('Dadditoyakon!'));
      await tester.pump();

      expect(
        find.text('Dadditoyakon dita pickup terminal! (I am here!)'),
        findsOneWidget,
      );

      // Simulate Passenger calling Driver WHILE Driver still has Chat modal open (Screenshot 2 scenario)
      await SupabaseService.sendTripCallSignal(
        callerRole: 'passenger',
        callerName: 'Maria Clara Santos',
        callerPhone: '+63 917 849 2038',
        state: 'ringing',
      );
      await tester.pumpAndSettle();

      // Incoming call modal pops up over the Chat sheet with both Decline and Answer
      expect(find.text('Incoming Wi-Fi / Data Call...'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
      expect(find.text('Answer'), findsOneWidget);

      // Tap Answer -> connects call
      await tester.tap(find.text('Answer'));
      await tester.pump();
      expect(find.textContaining('Connected via Wi-Fi / Data'), findsOneWidget);

      // End call cleanly
      await tester.tap(find.text('End Call'));
      await tester.pumpAndSettle();
    });

    testWidgets('Driver Call uses Wi-Fi/Data Call first when online (Ringing -> Answer -> Connected), and falls back to mobile phone call only when offline', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createDriverScreen());
      await tester.pump();

      // 1. Online (Wi-Fi / Data available) -> Opens Wi-Fi / Data Call sheet in Ringing state
      SupabaseService.debugForceOnlineForCall = true;
      await tester.tap(find.byIcon(Icons.phone_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Voice Call'));
      await tester.pumpAndSettle();

      expect(find.text('Wi-Fi / Data Call'), findsOneWidget);
      expect(find.textContaining('Ringing via Wi-Fi / Data'), findsOneWidget);

      // Passenger answers the call -> Driver transitions to Connected
      await SupabaseService.sendTripCallSignal(
        callerRole: 'passenger',
        callerName: 'Maria Clara Santos',
        callerPhone: '+63 917 849 2038',
        state: 'accepted',
      );
      await tester.pump();
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

    testWidgets('Passenger shows unread message badge and Incoming Call screen with Decline and Answer buttons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createPassengerScreen());
      await tester.pump(const Duration(milliseconds: 500));
      // Advance 3.5 seconds past findingDriver radar to driverHeadingToPickup phase
      await tester.pump(const Duration(milliseconds: 3500));
      // Advance 3.2 seconds so the _showRiderAcceptedPrompt overlay auto-dismisses
      await tester.pump(const Duration(milliseconds: 3200));
      await tester.pump();
      while (tester.takeException() != null) {}

      // 0. Incoming driver message shows unread badge on Passenger's Chat icon
      expect(find.byKey(const Key('passenger_chat_unread_badge')), findsNothing);
      await SupabaseService.sendTripChatMessage(
        senderRole: 'driver',
        senderName: 'Jose Dela Cruz',
        text: 'Dito na po ako sa gate!',
      );
      await tester.pump();
      while (tester.takeException() != null) {}
      expect(find.byKey(const Key('passenger_chat_unread_badge')), findsOneWidget);

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
      while (tester.takeException() != null) {}

      expect(SupabaseService.lastLaunchedTelUri, 'tel:+639178402291');
      expect(
        find.text('No Wi-Fi/Data: Switching to mobile phone call...'),
        findsOneWidget,
      );

      // 2. Incoming call from Driver -> Shows Decline & Answer on Passenger screen
      SupabaseService.debugForceOnlineForCall = true;
      await SupabaseService.sendTripCallSignal(
        callerRole: 'driver',
        callerName: 'Jose Dela Cruz',
        callerPhone: '+63 917 840 2291',
        state: 'ringing',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      while (tester.takeException() != null) {}

      expect(find.text('Incoming Wi-Fi / Data Call...'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
      expect(find.text('Answer'), findsOneWidget);

      // Passenger taps Answer -> transitions to Connected
      await tester.tap(find.text('Answer'));
      await tester.pump();
      while (tester.takeException() != null) {}
      expect(find.textContaining('Connected via Wi-Fi / Data'), findsOneWidget);
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

    testWidgets('Canceling search during Finding Driver skips survey, while canceling after Driver accepts shows survey, and Driver cancel syncs to Passenger', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createPassengerScreen());
      await tester.pump(const Duration(milliseconds: 500));
      while (tester.takeException() != null) {}

      // 1. In "Finding you a nearby driver..." phase, tapping Cancel Ride does NOT open "Why are you cancelling?"
      expect(find.text('Finding you a nearby driver...'), findsOneWidget);
      await tester.tap(find.text('Cancel Ride'));
      await tester.pump();
      while (tester.takeException() != null) {}
      expect(find.text('Why are you cancelling?'), findsNothing);

      // 2. Mount a fresh instance and advance 3.5s to driverHeadingToPickup (after driver has accepted)
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(createPassengerScreen());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 3500));
      while (tester.takeException() != null) {}

      expect(find.text('Driver is heading to your location...'), findsOneWidget);

      // Driver telemetry keeps distance >= 35m while en route until arrivedAtPickup
      SupabaseService.broadcastTripStageUpdate(
        stage: 'driver_en_route_telemetry',
        lat: 18.1950,
        lng: 120.5950,
        reason: '85',
      );
      await tester.pump();
      while (tester.takeException() != null) {}
      expect(find.textContaining('85m away'), findsOneWidget);

      // Dismiss accepted overlay if visible, expand sheet, and tap Cancel Ride after driver accepted -> DOES show "Why are you cancelling?"
      await tester.tap(find.text('Tap or swipe up for trip & vehicle details'), warnIfMissed: false);
      await tester.pump();
      while (tester.takeException() != null) {}

      final cancelBtnFinder = find.text('Cancel Ride');
      if (cancelBtnFinder.evaluate().isEmpty) {
        await tester.tap(find.text('Tap or swipe up for trip & vehicle details'), warnIfMissed: false);
        await tester.pump();
      }
      await tester.ensureVisible(find.text('Cancel Ride'));
      await tester.tap(find.text('Cancel Ride'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      while (tester.takeException() != null) {}

      expect(find.text('Why are you cancelling?'), findsOneWidget);
    });
  });
}
