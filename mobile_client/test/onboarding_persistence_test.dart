import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_client/core/services/onboarding_preferences_service.dart';
import 'package:mobile_client/core/services/session_cache_service.dart';
import 'package:mobile_client/features/auth/views/driver_application_status_screen.dart';
import 'package:mobile_client/features/auth/views/phone_input_screen.dart';
import 'package:mobile_client/features/auth/views/welcome_onboarding_screen.dart';
import 'package:mobile_client/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OnboardingPreferencesService', () {
    test('defaults to false when onboarding has not been completed or skipped', () async {
      final completed = await OnboardingPreferencesService.hasCompletedOnboarding();
      expect(completed, isFalse);
    });

    test('persists true when markOnboardingCompleted is called', () async {
      await OnboardingPreferencesService.markOnboardingCompleted();
      final completed = await OnboardingPreferencesService.hasCompletedOnboarding();
      expect(completed, isTrue);
    });

    test('resets to false when resetOnboarding is called', () async {
      await OnboardingPreferencesService.markOnboardingCompleted();
      expect(await OnboardingPreferencesService.hasCompletedOnboarding(), isTrue);

      await OnboardingPreferencesService.resetOnboarding();
      expect(await OnboardingPreferencesService.hasCompletedOnboarding(), isFalse);
    });
  });

  group('PasadaNorteMobileApp Routing', () {
    testWidgets('renders WelcomeOnboardingScreen when showLoginDirectly is false',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const PasadaNorteMobileApp(showLoginDirectly: false),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeOnboardingScreen), findsOneWidget);
      expect(find.byType(PhoneInputScreen), findsNothing);
    });

    testWidgets('renders PhoneInputScreen directly when showLoginDirectly is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const PasadaNorteMobileApp(showLoginDirectly: true),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PhoneInputScreen), findsOneWidget);
      expect(find.byType(WelcomeOnboardingScreen), findsNothing);
      expect(find.text('Log In'), findsOneWidget);
    });
  });

  group('WelcomeOnboardingScreen Skip and Finish Actions', () {
    testWidgets('tapping Skip marks onboarding as completed',
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

      expect(await OnboardingPreferencesService.hasCompletedOnboarding(), isFalse);

      final skipBtn = find.text('Skip');
      expect(skipBtn, findsOneWidget);
      await tester.tap(skipBtn);
      await tester.pumpAndSettle();

      expect(await OnboardingPreferencesService.hasCompletedOnboarding(), isTrue);
    });

    testWidgets('tapping Lets Get Started marks onboarding as completed',
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

      expect(await OnboardingPreferencesService.hasCompletedOnboarding(), isFalse);

      // Advance Slide 1 -> Slide 2
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Advance Slide 2 -> Slide 3
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      final getStartedBtn = find.text("Let's Get Started");
      expect(getStartedBtn, findsOneWidget);
      await tester.tap(getStartedBtn);
      await tester.pumpAndSettle();

      expect(await OnboardingPreferencesService.hasCompletedOnboarding(), isTrue);
    });
  });

  group('SessionCacheService', () {
    test('saves, reads, and clears a pending driver session', () async {
      expect(await SessionCacheService.getSavedSession(), isNull);

      await SessionCacheService.saveDriverSession(
        phoneNumber: '+639171234567',
        fullName: 'Juan Dela Cruz',
        isPendingReview: true,
      );

      final saved = await SessionCacheService.getSavedSession();
      expect(saved, isNotNull);
      expect(saved!.phoneNumber, '+639171234567');
      expect(saved.fullName, 'Juan Dela Cruz');
      expect(saved.role, 'driver');
      expect(saved.isPendingReview, isTrue);

      await SessionCacheService.clearSession();
      expect(await SessionCacheService.getSavedSession(), isNull);
    });

    testWidgets(
      'restores DriverApplicationStatusScreen with review hourglass asset when pending driver session is cached',
      (WidgetTester tester) async {
        const pendingDriver = CachedSession(
          phoneNumber: '+639171234567',
          fullName: 'Juan Dela Cruz',
          role: 'driver',
          isPendingReview: true,
        );

        await tester.pumpWidget(
          const PasadaNorteMobileApp(
            showLoginDirectly: true,
            savedSession: pendingDriver,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(DriverApplicationStatusScreen), findsOneWidget);
        expect(find.byType(PhoneInputScreen), findsNothing);
        expect(
          find.text('Your documents are currently being reviewed'),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Image &&
                w.image is AssetImage &&
                (w.image as AssetImage).assetName ==
                    'assets/images/review_hourglass.jpg',
          ),
          findsOneWidget,
        );
      },
    );
  });
}
