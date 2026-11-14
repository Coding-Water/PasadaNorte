import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_client/core/services/supabase_service.dart';
import 'package:mobile_client/core/theme/app_theme.dart';
import 'package:mobile_client/features/auth/models/user_model.dart';
import 'package:mobile_client/features/auth/views/driver_requirements_checklist_screen.dart';
import 'package:mobile_client/features/auth/views/face_scan_screen.dart';
import 'package:mobile_client/features/auth/views/id_upload_screen.dart';
import 'package:mobile_client/features/auth/views/otp_verification_screen.dart';
import 'package:mobile_client/features/auth/views/role_selection_screen.dart';
import 'package:mobile_client/features/auth/views/student_check_screen.dart';
import 'package:mobile_client/features/auth/views/senior_pwd_check_screen.dart';
import 'package:mobile_client/features/auth/views/user_details_input_screen.dart';
import 'package:mobile_client/features/fare/services/fare_calculator_service.dart';
import 'package:mobile_client/features/legal/views/privacy_policy_screen.dart';
import 'package:mobile_client/features/legal/views/terms_of_service_screen.dart';
import 'package:mobile_client/features/rider/views/passenger_account_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> fillPersonalInfoAndContinue(
    WidgetTester tester, {
    required String lastName,
    required String firstName,
    String gender = 'Female',
  }) async {
    expect(find.text('Fill Personal Info'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), lastName);
    await tester.enterText(fields.at(1), firstName);
    await tester.pump();

    // Select Gender
    final genderDropdown = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(genderDropdown);
    await tester.tap(genderDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(gender).last);
    await tester.pumpAndSettle();

    // Select Date of Birth
    final dobField = fields.at(5);
    await tester.ensureVisible(dobField);
    await tester.tap(dobField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Tap Continue
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  group('Static OTP & Registration Flow Tests (Rider and Driver)', () {
    testWidgets('OtpVerificationScreen follows minimalist layout and verifies static OTP 123456', (tester) async {
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

      expect(find.text('Enter OTP Code 🔐'), findsOneWidget);
      expect(find.text('Resend code'), findsOneWidget);
      expect(find.textContaining('Static OTP for Registration'), findsNothing);
      expect(find.textContaining('Attempts left:'), findsNothing);

      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(6));
      const code = '123456';
      for (int i = 0; i < 6; i++) {
        await tester.enterText(textFields.at(i), code[i]);
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));

      // Static 123456 must NOT bypass OTP verification when Supabase is offline
      expect(find.byType(RoleSelectionScreen), findsNothing);
      expect(find.byType(OtpVerificationScreen), findsOneWidget);
      expect(
        find.text('OTP verification service is unavailable. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('OtpVerificationScreen rejects legacy static OTP 202601 and invalid codes', (tester) async {
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

      // Enter legacy static code: 202601
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(6));
      const legacyCode = '202601';
      for (int i = 0; i < 6; i++) {
        await tester.enterText(textFields.at(i), legacyCode[i]);
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(RoleSelectionScreen), findsNothing);
      expect(
        find.text('OTP verification service is unavailable. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('Rider Registration Flow proceeds to FaceScanScreen without Skip bypass', (tester) async {
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

      // Verify Screen 1: Are you a Passenger or a Driver?
      expect(find.text('Are you a Passenger or a Driver?'), findsOneWidget);

      // Tap Passenger
      await tester.tap(find.text('Passenger'));
      await tester.pumpAndSettle();

      // Verify Screen 2: Are you a Student?
      expect(find.byType(StudentCheckScreen), findsOneWidget);
      expect(find.text('Are you a Student?'), findsOneWidget);

      // Tap Yes, Student
      await tester.tap(find.text('Yes, Student'));
      await tester.pumpAndSettle();

      // Verify Screen 3: User Details Input
      expect(find.byType(UserDetailsInputScreen), findsOneWidget);

      // Test Profile Picture picker sheet for Passengers (illustration avatars accepted)
      await tester.tap(find.bySemanticsLabel('Choose or upload profile picture'));
      await tester.pumpAndSettle();
      expect(find.text('Profile Picture'), findsOneWidget);
      expect(find.text('Illustration Avatars'), findsOneWidget);
      expect(find.text('Photo Requirements:'), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await fillPersonalInfoAndContinue(
        tester,
        lastName: 'Santos',
        firstName: 'Maria',
        gender: 'Female',
      );

      // Verify Individual Screen: ID Upload
      expect(find.byType(IdUploadScreen), findsOneWidget);

      // Auto-fill demo ID & consents
      await tester.tap(find.text('Auto-Fill'));
      await tester.pumpAndSettle();

      // Scroll and Tap Next to Face Scan
      final nextToFaceScan = find.text('Next: 1:1 Live Face Verification');
      await tester.scrollUntilVisible(nextToFaceScan, 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(nextToFaceScan);
      await tester.pumpAndSettle();

      // Verify Individual Screen: Face Scan (no Skip Testing bypass)
      expect(find.byType(FaceScanScreen), findsOneWidget);
      expect(find.text('Skip (Testing)'), findsNothing);
    });

    testWidgets('Driver Registration Flow requires 4-angle tricycle photos and removes Skip bypasses', (tester) async {
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

      // Tap Driver
      await tester.tap(find.text('Driver'));
      await tester.pumpAndSettle();

      // Verify User Details Input Screen for Driver
      expect(find.byType(UserDetailsInputScreen), findsOneWidget);

      await fillPersonalInfoAndContinue(
        tester,
        lastName: 'Ramos',
        firstName: 'Danilo',
        gender: 'Male',
      );

      // Verify Driver Requirements Checklist screen appears before IdUploadScreen
      expect(find.byType(DriverRequirementsChecklistScreen), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      expect(find.text('I Have Complete Requirements'), findsOneWidget);
      await tester.tap(find.text('I Have Complete Requirements'));
      await tester.pumpAndSettle();

      // Verify Individual Screen: Driver ID & Vehicle Compliance (DOB auto-filled)
      expect(find.byType(IdUploadScreen), findsOneWidget);
      expect(find.text('Driver & Vehicle Compliance'), findsOneWidget);
      expect(find.text('Tap to Select Date of Birth'), findsNothing);
      expect(find.text('Skip Tricycle Photos for now (Testing)'), findsNothing);

      // Verify Driver's License is the exclusive credential
      expect(find.text("Professional Driver's License (Valid)"), findsOneWidget);

      // Auto-fill demo ID, 4-angle vehicle photos & consents
      await tester.tap(find.text('Auto-Fill'));
      await tester.pumpAndSettle();

      // Scroll and Tap Next to Face Verification
      final nextToFaceScan = find.text('Next: 1:1 Live Face Verification');
      await tester.scrollUntilVisible(nextToFaceScan, 500, scrollable: find.byType(Scrollable).first);
      await tester.tap(nextToFaceScan);
      await tester.pumpAndSettle();

      expect(find.byType(FaceScanScreen), findsOneWidget);
      expect(find.text('Skip (Testing)'), findsNothing);
    });

    testWidgets('UserDetailsInputScreen blocks digits and symbols in Last, First, and Middle Name fields', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const UserDetailsInputScreen(
            phoneNumber: '+639171234567',
            role: UserRole.rider,
          ),
        ),
      );

      final fields = find.byType(TextFormField);
      // 0: Last Name, 1: First Name, 2: Middle Name
      await tester.enterText(fields.at(0), 'Dela Cruz123!@#');
      await tester.enterText(fields.at(1), 'Niño-Jose 99?\$%');
      await tester.enterText(fields.at(2), 'O\'Connor456><');
      await tester.pump();

      final lastField = tester.widget<TextFormField>(fields.at(0));
      final firstField = tester.widget<TextFormField>(fields.at(1));
      final middleField = tester.widget<TextFormField>(fields.at(2));

      expect(lastField.controller!.text, 'Dela Cruz');
      expect(firstField.controller!.text, 'Niño-Jose ');
      expect(middleField.controller!.text, 'O\'Connor');
    });

    testWidgets('Passenger Branching Flow: Not Student -> Not Senior/PWD -> Automatic Regular Passenger', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const RoleSelectionScreen(phoneNumber: '+639179998877'),
        ),
      );

      // Screen 1: Tap Passenger
      expect(find.text('Are you a Passenger or a Driver?'), findsOneWidget);
      await tester.tap(find.text('Passenger'));
      await tester.pumpAndSettle();

      // Screen 2: Tap Not a Student
      expect(find.byType(StudentCheckScreen), findsOneWidget);
      await tester.tap(find.text('Not a Student'));
      await tester.pumpAndSettle();

      // Screen 3: Senior/PWD check -> Tap Regular Passenger (Automatic Regular Passenger)
      expect(find.byType(SeniorPwdCheckScreen), findsOneWidget);
      expect(find.text('Are you a Senior Citizen or PWD?'), findsOneWidget);
      await tester.tap(find.text('Regular Passenger'));
      await tester.pumpAndSettle();

      // Screen 4: User Details Input Screen
      expect(find.byType(UserDetailsInputScreen), findsOneWidget);

      await fillPersonalInfoAndContinue(
        tester,
        lastName: 'Rizal',
        firstName: 'Jose',
        gender: 'Male',
      );

      // Individual ID Upload Screen verifies Regular Government ID requirement
      expect(find.byType(IdUploadScreen), findsOneWidget);
      expect(find.text('Upload Your Government ID'), findsOneWidget);
    });

    testWidgets('Instant Login recognizes newly registered users by phone', (tester) async {
      final existingRider = await SupabaseService.findUserByPhone('+639171234567');
      expect(existingRider, isNotNull);
      expect(existingRider!['role'], 'rider');

      final existingDriver = await SupabaseService.findUserByPhone('+639189876543');
      expect(existingDriver, isNotNull);
      expect(existingDriver!['role'], 'driver');
    });

    testWidgets('Account Settings opens Privacy Policy and Terms of Service screens', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const PassengerAccountScreen(
            fullName: 'Maria Santos',
            lockedCategory: PassengerCategory.regular,
            verifiedIdType: 'National ID (PhilSys)',
          ),
        ),
      );

      final helpTile = find.text('Help & Support');
      await tester.scrollUntilVisible(helpTile, 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(helpTile);
      await tester.pumpAndSettle();

      final privacyTile = find.text('Privacy Policy');
      await tester.tap(privacyTile);
      await tester.pumpAndSettle();

      expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
      expect(find.text('Effective Date: November 13, 2026'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      final termsTile = find.text('Terms of Service');
      await tester.tap(termsTile);
      await tester.pumpAndSettle();

      expect(find.byType(TermsOfServiceScreen), findsOneWidget);
      expect(find.text('Effective Date: November 13, 2026'), findsOneWidget);
    });

    testWidgets('FaceScanScreen displays selfie intro and guides through tilt left, tilt right, and blink once', (tester) async {
      SharedPreferences.setMockInitialValues({'pn_perm_camera_granted': true});
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const FaceScanScreen(
            phoneNumber: '+639171234567',
            fullName: 'Maria Santos',
            role: UserRole.rider,
            idType: 'National ID (PhilSys)',
            idPhotoPath: 'demo_id.jpg',
          ),
        ),
      );

      expect(find.text('Take a selfie to verify your identity'), findsOneWidget);
      await tester.ensureVisible(find.text('Next'));
      await tester.tap(find.text('Next'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Tilt left'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1250));
      expect(find.text('Now tilt right'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1250));
      expect(find.text('Face forward and blink'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1250));
      await tester.pumpAndSettle();

      expect(find.text('1:1 Face Match Verified'), findsOneWidget);
    });

    testWidgets('IdUploadScreen supports Files upload and shows uploaded filename', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const IdUploadScreen(
            phoneNumber: '+639171234567',
            fullName: 'Maria Santos',
            role: UserRole.rider,
          ),
        ),
      );

      expect(find.text('Files'), findsOneWidget);
      await tester.tap(find.text('Files'));
      await tester.pumpAndSettle();

      expect(find.textContaining('.pdf'), findsWidgets);
    });
  });
}
