import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
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

  // Local in-memory registry for rapid registration & login testing
  static final Map<String, Map<String, dynamic>> _localRegisteredUsers = {
    '+639171234567': {
      'id': 'mock_rider_001',
      'phone_number': '+639171234567',
      'full_name': 'Maria Santos',
      'role': 'rider',
      'id_type': '[REGULAR] National ID (PhilID)',
      'verification_status': 'approved',
    },
    '+639189876543': {
      'id': 'mock_driver_001',
      'phone_number': '+639189876543',
      'full_name': 'Danilo Ramos',
      'role': 'driver',
      'id_type': "Professional Driver's License",
      'verification_status': 'approved',
    },
  };

  // Saves 1:1 Face Verification result to Supabase users + biometric_access_logs tables
  static Future<String?> recordFaceVerification({
    required String fullName,
    required String phoneNumber,
    required UserRole role,
    PassengerCategory passengerCategory = PassengerCategory.regular,
    required String idType,
    required FaceVerificationResult result,
  }) async {
    final tagIdType = role == UserRole.rider
        ? '[${passengerCategory.name.toUpperCase()}] $idType'
        : idType;

    // Cache locally so instant login works immediately even if Supabase is offline
    _localRegisteredUsers[phoneNumber] = {
      'id': 'local_${DateTime.now().millisecondsSinceEpoch}',
      'phone_number': phoneNumber,
      'full_name': fullName,
      'role': role.name,
      'id_type': tagIdType,
      'verification_status': result.status == VerificationStatus.reUploadRequested
          ? 're_upload_requested'
          : result.status.name,
    };

    if (!_isConnected) return _localRegisteredUsers[phoneNumber]!['id'] as String;
    try {
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
    return _localRegisteredUsers[phoneNumber]!['id'] as String;
  }

  // Checks if a user account already exists by phone number for instant Login
  static Future<Map<String, dynamic>?> findUserByPhone(String phoneNumber) async {
    if (_localRegisteredUsers.containsKey(phoneNumber)) {
      return _localRegisteredUsers[phoneNumber];
    }
    if (!_isConnected) return null;
    try {
      final row = await Supabase.instance.client
          .from('users')
          .select()
          .eq('phone_number', phoneNumber)
          .maybeSingle();
      if (row != null) {
        _localRegisteredUsers[phoneNumber] = row;
      }
      return row;
    } catch (_) {
      return _localRegisteredUsers[phoneNumber];
    }
  }

  // Local registry of submitted driver applications
  static final Map<String, Map<String, dynamic>> _localDriverApplications = {};

  static String _guessContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.png')) return 'image/png';
    return 'image/jpeg';
  }

  static Future<String?> _uploadDriverDocument({
    required String phoneNumber,
    required String docType,
    required String? localPathOrName,
  }) async {
    if (localPathOrName == null || localPathOrName.trim().isEmpty) {
      return null;
    }
    if (localPathOrName.startsWith('http') ||
        localPathOrName.startsWith('storage://')) {
      return localPathOrName;
    }
    if (!_isConnected || kIsWeb) return localPathOrName;
    try {
      final file = File(localPathOrName);
      if (!file.existsSync()) return localPathOrName;
      final bytes = await file.readAsBytes();
      final rawName = localPathOrName.split(RegExp(r'[/\\]')).last;
      final safeName = rawName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final safePhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
      final storagePath =
          'applications/$safePhone/${docType}_${DateTime.now().millisecondsSinceEpoch}_$safeName';
      await Supabase.instance.client.storage
          .from('driver-documents')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _guessContentType(safeName),
            ),
          );
      return 'storage://driver-documents/$storagePath';
    } catch (e) {
      debugPrint('Supabase Storage upload fallback ($docType): $e');
      return localPathOrName;
    }
  }

  // Saves comprehensive Laoag City Driver Application & Vehicle Documentation
  static Future<String?> recordDriverApplication({
    required String fullName,
    required String phoneNumber,
    required DateTime birthDate,
    required String licensePhotoUrl,
    required String nbiClearanceUrl,
    required String policeOrBarangayClearanceUrl,
    required String profilePhotoUrl,
    String? fitToWorkCertUrl,
    required String motorcycleBrandModel,
    required int engineDisplacementCc,
    required int modelYear,
    required String plateOrMvFile,
    required String orPhotoUrl,
    required String crPhotoUrl,
    required bool isMotorcycleOwned,
    String? ownerAuthLetterUrl,
    String? ownerIdPhotoUrl,
    Map<String, String>? vehiclePhotos,
  }) async {
    // Upload actual files/photos to Supabase Storage when connected
    final uploaded = await Future.wait<String?>([
      _uploadDriverDocument(phoneNumber: phoneNumber, docType: 'license', localPathOrName: licensePhotoUrl),
      _uploadDriverDocument(phoneNumber: phoneNumber, docType: 'nbi', localPathOrName: nbiClearanceUrl),
      _uploadDriverDocument(phoneNumber: phoneNumber, docType: 'clearance', localPathOrName: policeOrBarangayClearanceUrl),
      _uploadDriverDocument(phoneNumber: phoneNumber, docType: 'profile', localPathOrName: profilePhotoUrl),
      _uploadDriverDocument(phoneNumber: phoneNumber, docType: 'fit_to_work', localPathOrName: fitToWorkCertUrl),
      _uploadDriverDocument(phoneNumber: phoneNumber, docType: 'or', localPathOrName: orPhotoUrl),
      _uploadDriverDocument(phoneNumber: phoneNumber, docType: 'cr', localPathOrName: crPhotoUrl),
      _uploadDriverDocument(phoneNumber: phoneNumber, docType: 'owner_auth', localPathOrName: ownerAuthLetterUrl),
      _uploadDriverDocument(phoneNumber: phoneNumber, docType: 'owner_id', localPathOrName: ownerIdPhotoUrl),
      _uploadDriverDocument(phoneNumber: phoneNumber, docType: 'trike_front', localPathOrName: vehiclePhotos?['Front View']),
      _uploadDriverDocument(phoneNumber: phoneNumber, docType: 'trike_back', localPathOrName: vehiclePhotos?['Back View']),
      _uploadDriverDocument(phoneNumber: phoneNumber, docType: 'trike_left', localPathOrName: vehiclePhotos?['Left Side View']),
      _uploadDriverDocument(phoneNumber: phoneNumber, docType: 'trike_right', localPathOrName: vehiclePhotos?['Right Side View']),
    ]);

    final dbRecord = {
      'phone_number': phoneNumber,
      'full_name': fullName,
      'birth_date': birthDate.toIso8601String().split('T').first,
      'age': (DateTime.now().difference(birthDate).inDays / 365.25).floor(),
      'license_photo_url': uploaded[0] ?? licensePhotoUrl,
      'nbi_clearance_url': uploaded[1] ?? nbiClearanceUrl,
      'police_or_barangay_clearance_url': uploaded[2] ?? policeOrBarangayClearanceUrl,
      'profile_photo_url': uploaded[3] ?? profilePhotoUrl,
      'fit_to_work_cert_url': uploaded[4],
      'motorcycle_brand_model': motorcycleBrandModel,
      'engine_displacement_cc': engineDisplacementCc,
      'model_year': modelYear,
      'plate_or_mv_file': plateOrMvFile,
      'or_photo_url': uploaded[5] ?? orPhotoUrl,
      'cr_photo_url': uploaded[6] ?? crPhotoUrl,
      'is_motorcycle_owned': isMotorcycleOwned,
      'owner_authorization_letter_url': uploaded[7],
      'owner_id_photo_url': uploaded[8],
      'vehicle_front_photo_url': uploaded[9],
      'vehicle_back_photo_url': uploaded[10],
      'vehicle_left_photo_url': uploaded[11],
      'vehicle_right_photo_url': uploaded[12],
      'application_status': 'submitted',
      'created_at': DateTime.now().toIso8601String(),
    };

    final localId = 'drv_app_${DateTime.now().millisecondsSinceEpoch}';
    _localDriverApplications[phoneNumber] = {
      'id': localId,
      ...dbRecord,
    };

    if (!_isConnected) return localId;
    try {
      final inserted = await Supabase.instance.client
          .from('driver_applications')
          .insert(dbRecord)
          .select()
          .maybeSingle();
      if (inserted != null && inserted['id'] != null) {
        final remoteId = inserted['id'].toString();
        _localDriverApplications[phoneNumber] = {
          ...dbRecord,
          'id': remoteId,
        };
        return remoteId;
      }
    } catch (e) {
      debugPrint('Supabase recordDriverApplication error: $e');
    }
    return localId;
  }

  /// Fetches the latest driver application row for [phoneNumber] from Supabase (or local cache).
  static Future<Map<String, dynamic>?> getDriverApplicationByPhone(
    String phoneNumber,
  ) async {
    if (_isConnected) {
      try {
        final row = await Supabase.instance.client
            .from('driver_applications')
            .select()
            .eq('phone_number', phoneNumber)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (row != null) {
          _localDriverApplications[phoneNumber] = row;
          return row;
        }
      } catch (e) {
        debugPrint('Supabase getDriverApplicationByPhone error: $e');
      }
    }
    return _localDriverApplications[phoneNumber];
  }

  /// Uploads any updated document files and resets application_status to 'submitted'.
  static Future<bool> resubmitDriverDocuments({
    required String phoneNumber,
    required Map<String, String> updatedLocalFilesByColumn,
  }) async {
    if (updatedLocalFilesByColumn.isEmpty) return false;

    final Map<String, dynamic> updates = {
      'application_status': 'submitted',
      'admin_notes': 'Driver resubmitted updated documents for MINC review.',
      'updated_at': DateTime.now().toIso8601String(),
    };

    for (final entry in updatedLocalFilesByColumn.entries) {
      final uploaded = await _uploadDriverDocument(
        phoneNumber: phoneNumber,
        docType: entry.key,
        localPathOrName: entry.value,
      );
      updates[entry.key] = uploaded ?? entry.value;
    }

    final cached = _localDriverApplications[phoneNumber];
    if (cached != null) {
      _localDriverApplications[phoneNumber] = {...cached, ...updates};
    }

    if (!_isConnected) return true;
    try {
      await Supabase.instance.client
          .from('driver_applications')
          .update(updates)
          .eq('phone_number', phoneNumber);
      return true;
    } catch (e) {
      debugPrint('Supabase resubmitDriverDocuments error: $e');
      return false;
    }
  }

  /// Marks a driver's resubmitted 1:1 Face Bio Scan as ready for MINC review.
  static Future<bool> resubmitDriverFaceScan({
    required String phoneNumber,
  }) async {
    final updates = <String, dynamic>{
      'application_status': 'submitted',
      'admin_notes': 'Driver completed a new 1:1 Face Bio Scan for MINC review.',
      'updated_at': DateTime.now().toIso8601String(),
    };
    final cached = _localDriverApplications[phoneNumber];
    if (cached != null) {
      _localDriverApplications[phoneNumber] = {...cached, ...updates};
    }
    if (!_isConnected) return true;
    try {
      await Supabase.instance.client
          .from('driver_applications')
          .update(updates)
          .eq('phone_number', phoneNumber);
      return true;
    } catch (e) {
      debugPrint('Supabase resubmitDriverFaceScan error: $e');
      return false;
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

  static RealtimeChannel? _dispatchChannel;
  static final StreamController<Map<String, dynamic>> _rideAcceptedStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>> _rideRequestedStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Reactive stream for ride acceptance events
  static Stream<Map<String, dynamic>> get onRideAccepted =>
      _rideAcceptedStreamController.stream;

  /// Reactive stream for incoming ride requests (Passenger -> Drivers)
  static Stream<Map<String, dynamic>> get onRideRequested =>
      _rideRequestedStreamController.stream;

  /// Initializes or retrieves the shared Supabase Realtime dispatch channel
  static RealtimeChannel? getDispatchChannel() {
    if (!_isConnected) return null;
    if (_dispatchChannel != null) return _dispatchChannel;
    try {
      final sb = Supabase.instance.client;
      _dispatchChannel = sb.channel('rides_dispatch');
      _dispatchChannel?.onBroadcast(
        event: 'ride_accepted',
        callback: (payload) {
          _rideAcceptedStreamController.add(payload);
        },
      ).onBroadcast(
        event: 'ride_requested',
        callback: (payload) {
          _rideRequestedStreamController.add(payload);
        },
      ).subscribe();
      return _dispatchChannel;
    } catch (_) {
      return null;
    }
  }

  /// Broadcasts ride request from passenger to online drivers via Supabase Realtime
  static Future<void> broadcastRideRequest({
    required String passengerName,
    required String pickupName,
    required double pickupLat,
    required double pickupLng,
    required String dropoffName,
    required double dropoffLat,
    required double dropoffLng,
    required double fare,
    required double distanceKm,
    required String passengerCategory,
    required String paymentMethod,
    String? deliveryNotes,
    String? rideId,
  }) async {
    final payload = <String, dynamic>{
      'ride_id': rideId ?? 'RIDE_${DateTime.now().millisecondsSinceEpoch}',
      'passenger_name': passengerName,
      'pickup_name': pickupName,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'dropoff_name': dropoffName,
      'dropoff_lat': dropoffLat,
      'dropoff_lng': dropoffLng,
      'fare': fare,
      'distance_km': distanceKm,
      'passenger_category': passengerCategory,
      'payment_method': paymentMethod,
      'delivery_notes': deliveryNotes,
      'requested_at': DateTime.now().toIso8601String(),
    };

    // 1. Local in-app stream dispatch (instantaneous reactivity if testing locally)
    _rideRequestedStreamController.add(payload);

    // 2. Realtime WebSocket broadcast across network
    if (_isConnected) {
      try {
        final channel = getDispatchChannel();
        await channel?.sendBroadcastMessage(
          event: 'ride_requested',
          payload: payload,
        );
      } catch (_) {}
    }
  }

  /// Broadcasts ride acceptance from DriverMapDutyScreen to connected passengers via Supabase Realtime
  static Future<void> broadcastRideAccepted({
    required String driverName,
    required String todaName,
    required String bodyNumber,
    required String plateNumber,
    required String phone,
    required String vehicleHeadline,
    required double driverLat,
    required double driverLng,
    Map<String, dynamic>? extra,
  }) async {
    final payload = <String, dynamic>{
      'driver_name': driverName,
      'toda': todaName,
      'body_number': bodyNumber,
      'plate_number': plateNumber,
      'phone': phone,
      'vehicle_headline': vehicleHeadline,
      'driver_lat': driverLat,
      'driver_lng': driverLng,
      'accepted_at': DateTime.now().toIso8601String(),
      if (extra != null) ...extra,
    };

    // 1. Local in-app stream dispatch (instantaneous UI reactivity)
    _rideAcceptedStreamController.add(payload);

    // 2. Realtime WebSocket broadcast across network
    if (_isConnected) {
      try {
        final channel = getDispatchChannel();
        await channel?.sendBroadcastMessage(
          event: 'ride_accepted',
          payload: payload,
        );
      } catch (_) {}
    }
  }
}
