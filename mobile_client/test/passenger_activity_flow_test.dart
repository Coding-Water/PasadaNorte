import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_client/features/fare/services/fare_calculator_service.dart';
import 'package:mobile_client/features/rider/models/activity_trip_model.dart';
import 'package:mobile_client/features/rider/views/passenger_activity_screen.dart';
import 'package:mobile_client/features/rider/views/passenger_service_hub_screen.dart';
import 'package:mobile_client/features/rider/views/ride_details_screen.dart';
import 'package:mobile_client/features/rider/views/share_receipt_sheet.dart';

void main() {
  testWidgets('PassengerServiceHubScreen renders Home, Activity, and Account bottom navigation tabs',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: PassengerServiceHubScreen(
          fullName: 'Juan Dela Cruz',
          lockedCategory: PassengerCategory.regular,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Bottom Navigation Bar Tabs
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);

    // Verify Home tab initial content
    expect(find.text('Hello, Juan!'), findsOneWidget);
    expect(find.text('Book a Ride'), findsOneWidget);
    expect(find.text('PasaDeliver (Padala / Pabili)'), findsOneWidget);

    // Tap Activity tab
    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();

    // Verify Activity screen rendered
    expect(find.byType(PassengerActivityScreen), findsOneWidget);
    expect(find.text('Ongoing'), findsOneWidget);
    expect(find.text('PasaDeliver'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Canceled'), findsOneWidget);

    // Tap Account tab
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();

    // Verify Account screen rendered
    expect(find.text('Government ID & Fare Status'), findsOneWidget);
    expect(find.text('Payment Methods'), findsOneWidget);
  });

  testWidgets('PassengerActivityScreen filters trips and navigates to Ride Details for Completed, Ongoing, and Canceled',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: PassengerActivityScreen(fullName: 'Juan Dela Cruz'),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Ongoing Tab (Default)
    expect(find.text('Ongoing'), findsOneWidget);
    expect(find.text('Track Route'), findsOneWidget);

    // Tap Ongoing trip card to open Image 3 style details
    await tester.tap(find.text('Track Route'));
    await tester.pumpAndSettle();

    expect(find.byType(RideDetailsScreen), findsOneWidget);
    expect(find.text('Your Active Ride'), findsOneWidget);
    expect(find.text('Share Receipt'), findsOneWidget);
    expect(find.text('Cancel Ride'), findsOneWidget);

    // Pop back to Activity
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    // 2. Completed Tab (Image 2 style)
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();

    expect(find.text('Fonacier Street, Brgy. 17'), findsOneWidget);

    // Tap Completed trip
    await tester.tap(find.text('Fonacier Street, Brgy. 17'));
    await tester.pumpAndSettle();

    expect(find.byType(RideDetailsScreen), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Share Receipt'), findsOneWidget);
    expect(find.text('Cancel Ride'), findsNothing); // Completed ride cannot be canceled

    // Tap Share Receipt to verify Image 4 sheet
    await tester.tap(find.text('Share Receipt'));
    await tester.pumpAndSettle();

    expect(find.byType(ShareReceiptSheet), findsOneWidget);
    expect(find.text('Share Receipt'), findsWidgets);
    expect(find.text('Recent people'), findsOneWidget);
    expect(find.text('Social media'), findsOneWidget);
    expect(find.text('WhatsApp'), findsWidgets);
    expect(find.text('Facebook'), findsWidgets);

    // Dismiss sheet and screen
    Navigator.of(tester.element(find.byType(ShareReceiptSheet))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    // 3. Canceled Tab
    await tester.ensureVisible(find.text('Canceled'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Canceled'));
    await tester.pumpAndSettle();

    expect(find.text('Robinsons Place Ilocos Norte'), findsOneWidget);
    await tester.tap(find.text('Robinsons Place Ilocos Norte'));
    await tester.pumpAndSettle();

    // In Canceled Ride Details: NO Share Receipt button, but Canceled indicator present
    expect(find.text('Canceled Ride • No fees charged'), findsOneWidget);
    expect(find.text('Share Receipt'), findsNothing);
  });
}
