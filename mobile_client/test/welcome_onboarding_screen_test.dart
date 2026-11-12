import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_client/features/auth/views/welcome_onboarding_screen.dart';

void main() {
  testWidgets('WelcomeOnboardingScreen renders clean Joyride hero and semantic action regions',
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

    // Verify design screen images are rendered
    expect(find.byType(Image), findsWidgets);

    // Verify semantic action buttons on Slide 1
    expect(find.bySemanticsLabel('Skip onboarding'), findsOneWidget);
    expect(find.bySemanticsLabel('Continue'), findsOneWidget);
    expect(find.bySemanticsLabel("Let's get started"), findsNothing);
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

    // Slide 1 -> Slide 2
    final continueBtn = find.bySemanticsLabel('Continue');
    expect(continueBtn, findsOneWidget);
    await tester.tap(continueBtn);
    await tester.pumpAndSettle();

    // Slide 2 -> Slide 3
    await tester.tap(find.bySemanticsLabel('Continue'));
    await tester.pumpAndSettle();

    // Final Action on Slide 3: Full-width "Let's get started"
    expect(find.bySemanticsLabel("Let's get started"), findsOneWidget);
    expect(find.bySemanticsLabel('Skip onboarding'), findsNothing);
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
