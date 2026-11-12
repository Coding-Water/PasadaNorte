import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_client/features/auth/views/welcome_onboarding_screen.dart';

void main() {
  testWidgets('WelcomeOnboardingScreen renders brand header, mockup, and bottom sheet',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: WelcomeOnboardingScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Brand Bar Elements
    expect(find.text('PasadaNorte'), findsOneWidget);
    expect(find.text('Laoag City • Ilocos Norte'), findsOneWidget);
    expect(find.text('Skip'), findsWidgets);

    // Verify First Slide Walkthrough Elements
    expect(find.text('LAOAG CITY COMMUTE'), findsOneWidget);
    expect(
      find.text('Welcome to PasadaNorte — Your Journey, Your Way'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Experience hassle-free tricycle mobility'),
      findsOneWidget,
    );

    // Verify Mockup Phone Elements for Slide 1 (Passenger Map Screen)
    expect(find.text('Where to in Laoag?'), findsOneWidget);
    expect(find.text('Laoag Plaza'), findsOneWidget);
    expect(find.text('5 Tricycles in Central Laoag'), findsOneWidget);

    // Verify Bottom Action Button
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('WelcomeOnboardingScreen advances through all 3 walkthrough slides',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: WelcomeOnboardingScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Slide 1 -> Slide 2 (Route & Fare)
    final continueBtn = find.text('Continue');
    expect(continueBtn, findsOneWidget);
    await tester.tap(continueBtn);
    await tester.pumpAndSettle();

    expect(find.text('ORDINANCE NO. 2023-005'), findsOneWidget);
    expect(
      find.text('Choose Your Ride — Approved City Fares'),
      findsOneWidget,
    );
    expect(find.text('Laoag Central Terminal'), findsOneWidget);
    expect(find.text('MMSU Laoag Campus'), findsOneWidget);
    expect(find.text('Pasada Regular'), findsOneWidget);
    expect(find.text('₱20.00'), findsOneWidget);

    // Slide 2 -> Slide 3 (Payment & TODA Queue)
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('FAIR TERMINAL PILA'), findsOneWidget);
    expect(
      find.text('Fair TODA Digital Pila & Flexible Payments'),
      findsOneWidget,
    );
    expect(find.text('Choose Payment Method'), findsOneWidget);
    expect(find.text('Cash Payment'), findsOneWidget);
    expect(find.text('Maya / GCash (QR Ph)'), findsOneWidget);
    expect(find.text('Laoag TODA Digital Pila'), findsOneWidget);

    // Final Action on Slide 3
    expect(find.text("Let's Get Started"), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
  });

  testWidgets('WelcomeOnboardingScreen meets accessibility tap target guidelines',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: WelcomeOnboardingScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
