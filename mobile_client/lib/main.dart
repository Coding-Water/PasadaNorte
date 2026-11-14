import 'dart:async';
import 'package:flutter/material.dart';
import 'core/services/onboarding_preferences_service.dart';
import 'core/services/session_cache_service.dart';
import 'core/services/supabase_service.dart';
import 'core/services/system_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/views/driver_application_status_screen.dart';
import 'features/auth/views/passenger_application_status_screen.dart';
import 'features/auth/views/phone_input_screen.dart';
import 'features/auth/views/welcome_onboarding_screen.dart';
import 'features/driver/views/driver_map_duty_screen.dart';
import 'features/driver/views/toda_queue_screen.dart';
import 'features/fare/services/fare_calculator_service.dart';
import 'features/rider/views/passenger_service_hub_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final hasCompletedOnboarding =
      await OnboardingPreferencesService.hasCompletedOnboarding();
  final savedSession = await SessionCacheService.getSavedSession();
  runApp(
    PasadaNorteMobileApp(
      showLoginDirectly: hasCompletedOnboarding,
      savedSession: savedSession,
    ),
  );
  unawaited(SupabaseService.initialize());
  unawaited(SystemNotificationService.initialize());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    debugPrint('First frame rendered successfully — UI is active and ready.');
  });
}

class PasadaNorteMobileApp extends StatefulWidget {
  final bool showLoginDirectly;
  final CachedSession? savedSession;

  const PasadaNorteMobileApp({
    super.key,
    this.showLoginDirectly = false,
    this.savedSession,
  });

  @override
  State<PasadaNorteMobileApp> createState() => _PasadaNorteMobileAppState();
}

class _PasadaNorteMobileAppState extends State<PasadaNorteMobileApp> {
  @override
  void initState() {
    super.initState();
    SystemNotificationService.onRoutePayload = _routeFromNotification;
    if (SystemNotificationService.pendingPayload != null) {
      final pending = SystemNotificationService.pendingPayload!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _routeFromNotification(pending);
      });
    }
  }

  Future<void> _routeFromNotification(String payload) async {
    final nav = SystemNotificationService.navigatorKey.currentState;
    if (nav == null) return;
    final session = await SessionCacheService.getSavedSession() ?? widget.savedSession;
    if (session == null) return;

    switch (payload) {
      case 'document_renewal_grace':
        nav.popUntil((route) => route.isFirst);
        break;
      case 'document_renewal_approved':
      case 'dispatch_offer':
        nav.popUntil((route) => route.isFirst);
        break;
      case 'pila_queued':
      case 'pila_rank_one':
        nav.popUntil((route) => route.isFirst);
        nav.push(
          MaterialPageRoute(
            builder: (_) => TodaQueueScreen(driverName: session.fullName),
          ),
        );
        break;
      case 'driver_application_status':
        if (session.role == 'driver') {
          nav.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => session.isPendingReview
                  ? DriverApplicationStatusScreen(
                      phoneNumber: session.phoneNumber,
                      fullName: session.fullName,
                    )
                  : DriverMapDutyScreen(fullName: session.fullName),
            ),
            (route) => false,
          );
        } else {
          final idTypeStr = session.idType ?? 'National ID (PhilID)';
          PassengerCategory lockedCat = PassengerCategory.regular;
          if (idTypeStr.toUpperCase().contains('STUDENT')) {
            lockedCat = PassengerCategory.student;
          } else if (idTypeStr.toUpperCase().contains('SENIOR') ||
              idTypeStr.toUpperCase().contains('PWD')) {
            lockedCat = PassengerCategory.senior;
          }
          nav.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => session.isPendingReview
                  ? PassengerApplicationStatusScreen(
                      phoneNumber: session.phoneNumber,
                      fullName: session.fullName,
                      passengerCategory: lockedCat,
                      idType: idTypeStr,
                    )
                  : PassengerServiceHubScreen(
                      fullName: session.fullName,
                      lockedCategory: lockedCat,
                      verifiedIdType: idTypeStr,
                    ),
            ),
            (route) => false,
          );
        }
        break;
      case 'trip_completed':
        nav.popUntil((route) => route.isFirst);
        break;
      case 'trip_accepted':
      case 'driver_arrived':
      case 'trip_in_transit':
        // Keep active tracking screen on top if open; no destructive pop needed.
        break;
      default:
        break;
    }
    SystemNotificationService.pendingPayload = null;
  }

  Widget _resolveInitialHome() {
    final session = widget.savedSession;
    if (session != null) {
      if (session.role == 'driver') {
        if (session.isPendingReview) {
          return DriverApplicationStatusScreen(
            phoneNumber: session.phoneNumber,
            fullName: session.fullName,
          );
        }
        return DriverMapDutyScreen(fullName: session.fullName);
      }

      final idTypeStr = session.idType ?? 'National ID (PhilID)';
      PassengerCategory lockedCat = PassengerCategory.regular;
      if (idTypeStr.toUpperCase().contains('STUDENT')) {
        lockedCat = PassengerCategory.student;
      } else if (idTypeStr.toUpperCase().contains('SENIOR') ||
          idTypeStr.toUpperCase().contains('PWD')) {
        lockedCat = PassengerCategory.senior;
      }
      if (session.isPendingReview) {
        return PassengerApplicationStatusScreen(
          phoneNumber: session.phoneNumber,
          fullName: session.fullName,
          passengerCategory: lockedCat,
          idType: idTypeStr,
        );
      }
      return PassengerServiceHubScreen(
        fullName: session.fullName,
        lockedCategory: lockedCat,
        verifiedIdType: idTypeStr,
      );
    }

    return widget.showLoginDirectly
        ? const PhoneInputScreen(initialIsRegisterMode: false)
        : const WelcomeOnboardingScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: SystemNotificationService.navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'PasadaNorte Laoag City',
      theme: AppTheme.lightTheme,
      home: _resolveInitialHome(),
    );
  }
}
