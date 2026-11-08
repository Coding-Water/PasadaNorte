import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/models/user_model.dart';
import '../../features/fare/services/fare_calculator_service.dart';
import 'face_verification_service.dart';
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
      );
      _isConnected = true;
      await syncAllFromSupabase();
    } catch (_) {
      _isConnected = false;
    }
  }

  // Pulls live Fare Guide Table, TODA Terminal Geofences, and 1:1 Face Verification Queue from Supabase PostgreSQL/PostGIS
  static Future<void> syncAllFromSupabase() async {
    if (!_isConnected) return;
    final sb = Supabase.instance.client;

    try {
      // 1. Sync Approved Fare Table (Objective 1 & 5b)
      final fareRow = await sb
          .from('fare_guide_table')
          .select()
          .eq('id', 1)
          .maybeSingle();

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
      final terminals = await sb.from('toda_terminals').select();
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
          .limit(25);

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
}
