import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/models/user_model.dart';
import '../../features/fare/services/fare_calculator_service.dart';
import 'face_verification_service.dart';
import 'location_service.dart';
import 'toda_queue_service.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://zrkkbknndavvprejskjy.supabase.co';
  static const String supabasePublishableKey =
      'sb_publishable_kMbiVj_on1b8XUdkTKvHmw_urG_F5sz';

  static bool _isConnected = false;
  static bool get isConnected => _isConnected;

  static SupabaseClient? get client =>
      _isConnected ? Supabase.instance.client : null;

  static Future<void> initialize() async {
    try {
      // ignore: deprecated_member_use
      await Supabase.initialize(
        url: supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: supabasePublishableKey,
      ).timeout(const Duration(seconds: 2));
      _isConnected = true;
      // Run cloud table sync in the background so runApp() renders the first frame immediately
      syncAllFromSupabase();
    } catch (_) {
      _isConnected = false;
    }
  }

  // Pulls live Fare Guide Table, TODA Terminal Geofences, and 1:1 Face Verification Queue from Supabase PostgreSQL/PostGIS
  static Future<void> syncAllFromSupabase() async {
    if (!_isConnected) return;
    // Allow emulator network stack and DNS (10.0.2.3) a moment to settle on cold start
    await Future.delayed(const Duration(milliseconds: 600));

    final sb = Supabase.instance.client;

    try {
      // 1. Sync Approved Fare Table (Objective 1 & 5b)
      final fareRow = await sb
          .from('fare_guide_table')
          .select()
          .eq('id', 1)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

      if (fareRow != null) {
        FareCalculatorService.updateFareConfig(
          regularFirstKmFare: (fareRow['regular_first_km_fare'] as num).toDouble(),
          discountedFirstKmFare: (fareRow['discounted_first_km_fare'] as num).toDouble(),
          succeedingKmRate: (fareRow['succeeding_km_rate'] as num).toDouble(),
          baseDistanceKm: (fareRow['base_distance_km'] as num?)?.toDouble() ?? 1.0,
          ordinanceLabel: fareRow['ordinance_label'] as String?,
          syncToCloud: false,
        );
      }

      // 2. Sync TODA Terminal Geofence Radii (Objective 4 & 5b)
      final terminals = await sb
          .from('toda_terminals')
          .select()
          .timeout(const Duration(seconds: 4));
      for (final row in terminals) {
        final id = row['id'] as String?;
        final radius = (row['radius_meters'] as num?)?.toDouble();
        if (id != null && radius != null) {
          TodaQueueService.updateAdminPilaRadius(id, radius, syncToCloud: false);
        }
      }

      // 3. Sync 1:1 Face Verification Records (Objective 2 & 5b)
      final usersRows = await sb
          .from('users')
          .select()
          .order('created_at', ascending: false)
          .limit(25)
          .timeout(const Duration(seconds: 4));

      if (usersRows.isNotEmpty) {
        final List<FaceVerificationRecord> fetched = [];
        for (final r in usersRows) {
          final statusStr = (r['verification_status'] as String?) ?? 'pending';
          final status = VerificationStatus.values.firstWhere(
            (e) => e.name == statusStr || (statusStr == 're_upload_requested' && e == VerificationStatus.reUploadRequested),
            orElse: () => VerificationStatus.pending,
          );
          final roleStr = (r['role'] as String?) ?? 'rider';
          final role = roleStr == 'driver' ? UserRole.driver : UserRole.rider;

          fetched.add(
            FaceVerificationRecord(
              id: (r['id'] as String?) ?? 'VER-SB',
              fullName: (r['full_name'] as String?) ?? 'Unknown User',
              phoneNumber: (r['phone_number'] as String?) ?? '',
              role: role,
              idType: (r['id_type'] as String?) ?? 'Government ID',
              similarityScorePercent: (r['ai_similarity_percent'] as num?)?.toDouble() ?? 80.0,
              processingTimeMs: (r['verification_latency_ms'] as num?)?.toInt() ?? 1400,
              status: status,
              adminNote: (r['admin_review_note'] as String?) ?? '',
              timestamp: DateTime.tryParse((r['created_at'] as String?) ?? '') ?? DateTime.now(),
            ),
          );
        }
        FaceVerificationService.verificationQueue
          ..clear()
          ..addAll(fetched);
      }
    } catch (_) {
      // Keeps local state if offline
    }
  }

  // Saves updated Laoag City Fare Guide Table to Supabase
  static Future<void> upsertFareConfig(FareConfig config) async {
    if (!_isConnected) return;
    try {
      await Supabase.instance.client.from('fare_guide_table').upsert({
        'id': 1,
        'ordinance_label': config.ordinanceLabel,
        'regular_first_km_fare': config.regularFirstKmFare,
        'discounted_first_km_fare': config.discountedFirstKmFare,
        'succeeding_km_rate': config.succeedingKmRate,
        'base_distance_km': config.baseDistanceKm,
        'statutory_discount_share_rate': config.succeedingDiscountRate,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  // Saves updated TODA Geofence Radius to Supabase PostGIS table
  static Future<void> updateTerminalRadius(String terminalId, double radiusMeters) async {
    if (!_isConnected) return;
    try {
      await Supabase.instance.client
          .from('toda_terminals')
          .update({'radius_meters': radiusMeters})
          .eq('id', terminalId);
    } catch (_) {}
  }

  // Saves 1:1 Face Verification result to Supabase users + biometric_access_logs tables
  static Future<String?> recordFaceVerification({
    required String fullName,
    required String phoneNumber,
    required UserRole role,
    PassengerCategory passengerCategory = PassengerCategory.regular,
    required String idType,
    required FaceVerificationResult result,
  }) async {
    if (!_isConnected) return null;
    try {
      final tagIdType = role == UserRole.rider
          ? '[${passengerCategory.name.toUpperCase()}] $idType'
          : idType;

      final inserted = await Supabase.instance.client
          .from('users')
          .upsert({
            'phone_number': phoneNumber,
            'full_name': fullName,
            'role': role.name,
            'id_type': tagIdType,
            'informed_consent_signed': true,
            'informed_consent_timestamp': DateTime.now().toIso8601String(),
            'ai_similarity_percent': result.similarityScorePercent,
            'verification_latency_ms': result.processingTimeMs,
            'verification_status': result.status == VerificationStatus.reUploadRequested
                ? 're_upload_requested'
                : result.status.name,
            'verification_images_deleted': result.verificationImagesDeleted,
            'admin_review_note': result.decisionNote,
          }, onConflict: 'phone_number')
          .select()
          .maybeSingle();

      if (inserted != null && inserted['id'] != null) {
        final userId = inserted['id'] as String;
        await Supabase.instance.client.from('biometric_access_logs').insert({
          'target_user_id': userId,
          'action_type': result.isApproved
              ? '1_TO_1_AUTO_APPROVED_IMAGES_PURGED'
              : 'REFERRED_TO_ADMIN_PORTAL_QUEUE',
        });
        return userId;
      }
    } catch (_) {}
    return null;
  }

  // Checks if a user account already exists by phone number for instant Login
  static Future<Map<String, dynamic>?> findUserByPhone(String phoneNumber) async {
    if (!_isConnected) return null;
    try {
      final row = await Supabase.instance.client
          .from('users')
          .select()
          .eq('phone_number', phoneNumber)
          .maybeSingle();
      return row;
    } catch (_) {
      return null;
    }
  }

  // Updates Admin decision (Approve / Reject / Ask Clearer Photos) in Supabase
  static Future<void> updateAdminReviewDecision({
    required String phoneNumber,
    required VerificationStatus newStatus,
    required String adminNote,
  }) async {
    if (!_isConnected) return;
    try {
      final dbStatus = newStatus == VerificationStatus.reUploadRequested
          ? 're_upload_requested'
          : newStatus.name;

      final updated = await Supabase.instance.client
          .from('users')
          .update({
            'verification_status': dbStatus,
            'verification_images_deleted': newStatus == VerificationStatus.approved,
            'admin_review_note': adminNote,
          })
          .eq('phone_number', phoneNumber)
          .select()
          .maybeSingle();

      if (updated != null && updated['id'] != null) {
        await Supabase.instance.client.from('biometric_access_logs').insert({
          'target_user_id': updated['id'],
          'action_type': 'ADMIN_REVIEW_${dbStatus.toUpperCase()}',
        });
      }
    } catch (_) {}
  }

  // 1. Broadcasts live Driver GPS telemetry to Supabase active_rides table with velocity sanity checks
  static Future<bool> broadcastDriverTelemetry({
    required String rideId,
    required double latitude,
    required double longitude,
    required double heading,
    required String stage,
    bool? isMocked,
  }) async {
    // Velocity Sanity Check (Pillar 5): Reject impossible speed jumps / teleportation (> 80 km/h)
    final isPhysicallyPlausible = LocationService.validateGpsVelocitySanity(
      newLat: latitude,
      newLng: longitude,
    );
    if (!isPhysicallyPlausible) {
      return false; // Suppress erratic GPS sensor glitch
    }

    if (!_isConnected) return false;

    // Resilience: Retry with exponential backoff on intermittent network drops
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final payload = <String, dynamic>{
          'ride_id': rideId,
          'latitude': latitude,
          'longitude': longitude,
          'heading': heading,
          'stage': stage,
          'updated_at': DateTime.now().toIso8601String(),
        };
        if (isMocked != null) {
          payload['is_mocked'] = isMocked;
        }
        await Supabase.instance.client
            .from('driver_telemetry')
            .upsert(payload, onConflict: 'ride_id');
        return true;
      } catch (_) {
        if (attempt < 3) {
          await Future.delayed(Duration(milliseconds: 250 * attempt));
        }
      }
    }
    return false;
  }

  // 2. Broadcasts Red Alert / Emergency SOS to Laoag PNP & TODA Admin Portal
  static Future<bool> broadcastSosAlert({
    required String driverName,
    required double latitude,
    required double longitude,
    String reason = 'DRIVER_TRIGGERED_EMERGENCY_SOS',
  }) async {
    if (!_isConnected) return true; // Graceful fallback
    try {
      await Supabase.instance.client.from('emergency_sos_alerts').insert({
        'driver_name': driverName,
        'latitude': latitude,
        'longitude': longitude,
        'alert_reason': reason,
        'status': 'ACTIVE_DISPATCHED',
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (_) {
      return true;
    }
  }

  // 3. Records completed trip to Supabase paratransit analytics
  static Future<void> recordCompletedTrip({
    required String driverName,
    required double fare,
    required double distanceKm,
    required String passengerName,
    required String paymentMethod,
    required String destination,
  }) async {
    if (!_isConnected) return;
    try {
      await Supabase.instance.client.from('completed_trips').insert({
        'driver_name': driverName,
        'fare_amount': fare,
        'distance_km': distanceKm,
        'passenger_name': passengerName,
        'payment_method': paymentMethod,
        'dropoff_location': destination,
        'completed_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // PILLAR 3: PRIVACY & SECURE STORAGE SENTINEL (RA 10173 & NPC CIRCULAR 2023-03)
  // ---------------------------------------------------------------------------

  /// Generates a time-expiring signed URL (default 300 seconds / 5 minutes)
  /// from a private Supabase Storage bucket (e.g. 'id-documents', 'biometric-vault').
  /// Prevents exposing government IDs and face photos via public CDN URLs.
  static Future<String?> createPrivateDocumentSignedUrl({
    required String bucket,
    required String path,
    int expiresInSeconds = 300,
  }) async {
    if (!_isConnected) return null;
    try {
      final signedUrl = await Supabase.instance.client.storage
          .from(bucket)
          .createSignedUrl(path, expiresInSeconds);
      return signedUrl;
    } catch (_) {
      return null;
    }
  }

  /// Explicitly purges raw biometric capture image from private storage
  /// immediately upon approval or admin decision (NPC Circular No. 2023-03).
  static Future<bool> purgeBiometricStagingImage({
    required String bucket,
    required String path,
  }) async {
    if (!_isConnected) return true;
    try {
      await Supabase.instance.client.storage.from(bucket).remove([path]);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Appends an access/review audit entry to biometric_access_logs
  static Future<void> logBiometricAccess({
    required String targetUserId,
    required String actionType,
  }) async {
    if (!_isConnected) return;
    try {
      await Supabase.instance.client.from('biometric_access_logs').insert({
        'target_user_id': targetUserId,
        'action_type': actionType,
        'logged_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }
}
