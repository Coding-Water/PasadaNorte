import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_client/core/services/supabase_service.dart';
import 'package:mobile_client/core/theme/app_theme.dart';
import 'package:mobile_client/features/auth/views/face_scan_screen.dart';
import 'package:mobile_client/features/auth/views/id_upload_screen.dart';
import 'package:mobile_client/features/auth/views/otp_verification_screen.dart';
import 'package:mobile_client/features/auth/views/role_selection_screen.dart';
import 'package:mobile_client/features/driver/views/driver_map_duty_screen.dart';
import 'package:mobile_client/features/rider/views/passenger_service_hub_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Static OTP & Registration Flow Tests (Rider and Driver)', () {
    testWidgets('OtpVerificationScreen displays static OTP 123456 and auto-fills seamlessly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const OtpVerificationScreen(phoneNumber: '+639171234567'),
        ),
      );

      // Verify static OTP banner is shown with 123456
      expect(find.textContaining('123456'), findsWidgets);
      expect(find.text('Auto-Fill Static OTP (123456)'), findsOneWidget);

      // Tap the auto-fill button
      await tester.tap(find.text('Auto-Fill Static OTP (123456)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));

      // Successfully verifies and navigates to RoleSelectionScreen
      expect(find.byType(RoleSelectionScreen), findsOneWidget);
      expect(find.text('Are you a Passenger or a Driver?'), findsOneWidget);
    });

    testWidgets('OtpVerificationScreen rejects invalid OTP and shows helpful hint', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const OtpVerificationScreen(phoneNumber: '+639171234567'),
        ),
      );

      // Enter an invalid 6-digit code: 999999
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(6));

      for (int i = 0; i < 6; i++) {
        await tester.enterText(textFields.at(i), '9');
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));

      // Should display invalid OTP snackbar indicating 123456
      expect(find.textContaining('Invalid OTP. Static test OTP is 123456'), findsOneWidget);
    });

    testWidgets('Rider Registration Flow from RoleSelectionScreen to PassengerServiceHubScreen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const RoleSelectionScreen(phoneNumber: '+639171234567'),
        ),
      );

      // Fill full name
      final nameField = find.byType(TextFormField);
      await tester.enterText(nameField, 'Maria Santos');
      await tester.pump();

      // Ensure button is visible & tap
      final proceedToIdBtn = find.text('Proceed to ID & Face Verification');
      await tester.ensureVisible(proceedToIdBtn);
      await tester.tap(proceedToIdBtn);
      await tester.pumpAndSettle();

      expect(find.byType(IdUploadScreen), findsOneWidget);

      // Auto-fill demo ID & consents
      await tester.tap(find.text('Auto-Fill'));
      await tester.pumpAndSettle();

      // Scroll and Tap Next to Face Scan
      final nextToFaceScan = find.text('Next: 1:1 Live Face Verification');
      await tester.scrollUntilVisible(nextToFaceScan, 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(nextToFaceScan);
      await tester.pumpAndSettle();

      expect(find.byType(FaceScanScreen), findsOneWidget);

      // Trigger instant verification
      await tester.tap(find.text('Verify Now'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      // Dialog pops up
      expect(find.text('1:1 Face Match Verified'), findsOneWidget);

      // Tap Continue to PasadaNorte
      await tester.tap(find.text('Continue to PasadaNorte'));
      await tester.pumpAndSettle();

      // Verifies landing on PassengerServiceHubScreen with rider greeting
      expect(find.byType(PassengerServiceHubScreen), findsOneWidget);
      expect(find.textContaining('Hello, Maria!'), findsOneWidget);
    });

    testWidgets('Driver Registration Flow from RoleSelectionScreen to DriverMapDutyScreen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const RoleSelectionScreen(phoneNumber: '+639189876543'),
        ),
      );

      // Fill full name
      final nameField = find.byType(TextFormField);
      await tester.enterText(nameField, 'Danilo Ramos');
      await tester.pump();

      // Select Tricycle Driver (TODA)
      await tester.tap(find.text('Tricycle Driver (TODA)'));
      await tester.pumpAndSettle();

      // Proceed to ID and Face Verification
      final proceedToIdBtn = find.text('Proceed to ID & Face Verification');
      await tester.ensureVisible(proceedToIdBtn);
      await tester.tap(proceedToIdBtn);
      await tester.pumpAndSettle();

      expect(find.byType(IdUploadScreen), findsOneWidget);
      expect(find.text('Step 1: Driver ID & Tricycle Photos'), findsOneWidget);

      // Auto-fill demo ID & 4 tricycle photos
      await tester.tap(find.text('Auto-Fill'));
      await tester.pumpAndSettle();

      // Scroll and Tap Next to Face Verification
      final nextToFaceScan = find.text('Next: 1:1 Live Face Verification');
      await tester.scrollUntilVisible(nextToFaceScan, 500, scrollable: find.byType(Scrollable).first);
      await tester.tap(nextToFaceScan);
      await tester.pumpAndSettle();

      expect(find.byType(FaceScanScreen), findsOneWidget);

      // Trigger instant verification
      await tester.tap(find.text('Verify Now'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      expect(find.text('1:1 Face Match Verified'), findsOneWidget);

      // Tap Continue to PasadaNorte
      await tester.tap(find.text('Continue to PasadaNorte'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Verifies landing on DriverMapDutyScreen
      expect(find.byType(DriverMapDutyScreen), findsOneWidget);
    });

    testWidgets('Instant Login recognizes newly registered users by phone', (tester) async {
      final existingRider = await SupabaseService.findUserByPhone('+639171234567');
      expect(existingRider, isNotNull);
      expect(existingRider!['role'], 'rider');

      final existingDriver = await SupabaseService.findUserByPhone('+639189876543');
      expect(existingDriver, isNotNull);
      expect(existingDriver!['role'], 'driver');
    });
  });
}
