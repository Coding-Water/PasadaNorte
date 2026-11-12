import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_client/features/auth/views/welcome_onboarding_screen.dart';

void main() {
  testWidgets('WelcomeOnboardingScreen renders clean Joyride hero, phone mockup, and bottom sheet',
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

    // Verify top bar with [4/4] and [Skip] is REMOVED
    expect(find.text('4/4'), findsNothing);
    expect(find.text('Perms'), findsNothing);
    expect(find.text('LAOAG CITY COMMUTE'), findsNothing);

    // Verify First Slide Walkthrough Elements (Matching Joyride Page 17)
    expect(
      find.text('Welcome to PasadaNorte - Your\nJourney, Your Way'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Get ready to experience hassle-free transportation'),
      findsOneWidget,
    );

    // Verify phone mockup renders image asset
    expect(find.byType(Image), findsWidgets);

    // Verify Bottom Action Buttons (50/50 Split Skip and Continue)
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('WelcomeOnboardingScreen advances through all 3 Joyride walkthrough slides',
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

    // Slide 1 -> Slide 2 (Route & Choose Ride - Matching Joyride Page 18)
    final continueBtn = find.text('Continue');
    expect(continueBtn, findsOneWidget);
    await tester.tap(continueBtn);
    await tester.pumpAndSettle();

    expect(
      find.text('Choose Your Ride -\nTailored to Your Needs'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Select your preferred mode of transportation'),
      findsOneWidget,
    );

    // Slide 2 -> Slide 3 (Payment Methods - Matching Joyride Page 19)
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(
      find.text('Secure Payments &\nSeamless Transactions'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Say hello to convenience payments'),
      findsOneWidget,
    );

    // Final Action on Slide 3: Full-width "Let's Get Started"
    expect(find.text("Let's Get Started"), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
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
