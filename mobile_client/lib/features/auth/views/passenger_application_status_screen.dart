import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/session_cache_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/system_notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../fare/services/fare_calculator_service.dart';
import '../../rider/views/passenger_service_hub_screen.dart';
import '../models/user_model.dart';
import 'face_scan_screen.dart';
import 'welcome_onboarding_screen.dart';

class PassengerApplicationStatusScreen extends StatefulWidget {
  final String phoneNumber;
  final String fullName;
  final PassengerCategory passengerCategory;
  final String idType;
  final String? idPhotoPath;
  final String? profilePhotoPath;

  const PassengerApplicationStatusScreen({
    super.key,
    required this.phoneNumber,
    required this.fullName,
    this.passengerCategory = PassengerCategory.regular,
    this.idType = 'National ID (PhilID)',
    this.idPhotoPath,
    this.profilePhotoPath,
  });

  @override
  State<PassengerApplicationStatusScreen> createState() =>
      _PassengerApplicationStatusScreenState();
}

class _PassengerApplicationStatusScreenState
    extends State<PassengerApplicationStatusScreen> {
  String _status = 'pending';
  String? _adminNote;
  bool _isRefreshing = false;
  bool _isUploadingId = false;
  Timer? _pollTimer;
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSub;
  final ImagePicker _picker = ImagePicker();
  String? _reuploadedIdPath;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
    _subscribeRealtime();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _fetchStatus(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _realtimeSub?.cancel();
    super.dispose();
  }

  void _subscribeRealtime() {
    try {
      _realtimeSub = Supabase.instance.client
          .from('users')
          .stream(primaryKey: ['id'])
          .eq('phone_number', widget.phoneNumber)
          .listen((rows) {
        if (!mounted || rows.isEmpty) return;
        _applyRowUpdate(rows.first);
      }, onError: (_) {});
    } catch (_) {}
  }

  void _applyRowUpdate(Map<String, dynamic> row) {
    final newStatus =
        (row['verification_status'] as String?) ?? 'pending';
    final newNote = row['admin_review_note'] as String?;

    final statusChanged = newStatus != _status;
    if (statusChanged) {
      if (newStatus == 'approved') {
        SessionCacheService.saveRiderSession(
          phoneNumber: widget.phoneNumber,
          fullName: widget.fullName,
          idType: widget.idType,
          isPendingReview: false,
        );
        SystemNotificationService.showDriverApplicationNotification(
          title: 'PasadaNorte Application Approved!',
          body:
              'Welcome, ${widget.fullName}! Your passenger verification passed. You can now book rides.',
          payload: 'passenger_approved',
        );
      } else if (newStatus == 're_upload_requested' ||
          newStatus == 'resubmission_requested') {
        SystemNotificationService.showDriverApplicationNotification(
          title: 'PasadaNorte Action Required',
          body: newNote ??
              'Admin requested resubmission of your ID or 1:1 Face Bio Scan.',
          payload: 'passenger_resubmit',
        );
      } else if (newStatus == 'rejected') {
        SystemNotificationService.showDriverApplicationNotification(
          title: 'PasadaNorte Application Rejected',
          body: newNote ?? 'Your passenger application was rejected.',
          payload: 'passenger_rejected',
        );
      }
    }

    if (mounted) {
      setState(() {
        _status = newStatus;
        _adminNote = newNote;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _fetchStatus({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _isRefreshing = true);
    }
    final row =
        await SupabaseService.fetchRiderApplicationByPhone(widget.phoneNumber);
    if (!mounted) return;
    if (row != null) {
      _applyRowUpdate(row);
    } else {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _reuploadId(ImageSource? source, {bool pickFile = false}) async {
    String? path;
    try {
      if (pickFile) {
        final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        );
        if (result.isNotEmpty && result.first.path != null) {
          path = result.first.path;
        }
      } else if (source != null) {
        final file = await _picker.pickImage(
          source: source,
          maxWidth: 1200,
          imageQuality: 85,
        );
        path = file?.path;
      }
    } catch (_) {
      if (mounted) {
              }
      return;
    }

    if (path == null) return;
    setState(() => _isUploadingId = true);

    await SupabaseService.resubmitRiderIdDocument(
      phoneNumber: widget.phoneNumber,
      localPath: path,
    );

    if (!mounted) return;
    setState(() {
      _reuploadedIdPath = path;
      _isUploadingId = false;
    });
        _fetchStatus();
  }

  Future<void> _redoFaceScan() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaceScanScreen(
          phoneNumber: widget.phoneNumber,
          fullName: widget.fullName,
          role: UserRole.rider,
          passengerCategory: widget.passengerCategory,
          idType: widget.idType,
          idPhotoPath: _reuploadedIdPath ?? widget.idPhotoPath ?? '',
          profilePhotoPath: widget.profilePhotoPath,
          isResubmissionRedo: true,
        ),
      ),
    );
    if (mounted) {
      _fetchStatus();
    }
  }

  void _proceedToPasadaNorte() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => PassengerServiceHubScreen(
          fullName: widget.fullName,
          lockedCategory: widget.passengerCategory,
          verifiedIdType: widget.idType,
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _switchAccount() async {
    await SessionCacheService.clearSession();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const WelcomeOnboardingScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isApproved = _status == 'approved';
    final isResubmit =
        _status == 're_upload_requested' || _status == 'resubmission_requested';
    final isRejected = _status == 'rejected';

    final noteLower = (_adminNote ?? '').toLowerCase();
    final mentionsId = noteLower.contains('submitted id') ||
        noteLower.contains('valid id') ||
        noteLower.contains('government id');
    final mentionsFace =
        noteLower.contains('face') || noteLower.contains('bio scan');
    final showBothResubmit = !mentionsId && !mentionsFace;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Passenger Verification Status',
          style: TextStyle(
            color: AppTheme.primarySlate,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _isRefreshing ? null : () => _fetchStatus(),
            tooltip: 'Refresh Status',
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                    color: AppTheme.primarySlate,
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              if (!isApproved && !isResubmit && !isRejected)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/review_hourglass.jpg',
                    width: 160,
                    height: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppTheme.accentEmerald.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.hourglass_top_rounded,
                        size: 56,
                        color: AppTheme.accentEmerald,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: (isApproved
                            ? AppTheme.accentEmerald
                            : (isResubmit ? Colors.orange : Colors.red))
                        .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isApproved
                        ? Icons.verified_user_rounded
                        : (isResubmit
                            ? Icons.assignment_late_rounded
                            : Icons.cancel_rounded),
                    size: 52,
                    color: isApproved
                        ? AppTheme.accentEmerald
                        : (isResubmit ? Colors.orange : Colors.red),
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                isApproved
                    ? 'You Are Verified!'
                    : (isResubmit
                        ? 'Resubmission Required'
                        : (isRejected
                            ? 'Application Rejected'
                            : 'Under Review')),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primarySlate,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isApproved
                    ? 'Your ID and 1:1 Face Bio Scan passed admin verification. Welcome to PasadaNorte, ${widget.fullName}!'
                    : (isResubmit
                        ? 'An admin reviewed your passenger verification and requested updated files below.'
                        : (isRejected
                            ? 'Your passenger registration did not pass verification.'
                            : 'Your ID & face verification are currently being reviewed by a PasadaNorte Admin.')),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.45,
                  color: Colors.grey.shade700,
                ),
              ),
              if (!isApproved && !isResubmit && !isRejected) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.accentEmerald.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 20,
                        color: AppTheme.accentEmeraldDark,
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Estimated review time: 1 hour or less.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accentEmeraldDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'You will receive a notification on this device as soon as your account is approved. No driver requirements are needed for passengers.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
              if (_adminNote != null &&
                  _adminNote!.trim().isNotEmpty &&
                  (isResubmit || isRejected)) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isRejected
                        ? const Color(0xFFFEF2F2)
                        : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isRejected
                          ? Colors.red.shade200
                          : Colors.amber.shade300,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRejected
                            ? 'Rejection Reason:'
                            : 'Admin Objection / Reason:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isRejected
                              ? Colors.red.shade800
                              : Colors.amber.shade900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _adminNote!,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: AppTheme.primarySlate,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (isResubmit) ...[
                const SizedBox(height: 20),
                if (mentionsId || showBothResubmit) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.badge_rounded,
                              size: 20,
                              color: AppTheme.primarySlate,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Re-upload ${widget.idType}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primarySlate,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_isUploadingId)
                          const Center(child: CircularProgressIndicator())
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _reuploadId(ImageSource.camera),
                                icon: const Icon(Icons.camera_alt_rounded,
                                    size: 16),
                                label: const Text('Camera'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _reuploadId(ImageSource.gallery),
                                icon: const Icon(Icons.photo_library_rounded,
                                    size: 16),
                                label: const Text('Gallery'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _reuploadId(null, pickFile: true),
                                icon: const Icon(Icons.upload_file_rounded,
                                    size: 16),
                                label: const Text('Files'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (mentionsFace || showBothResubmit)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _redoFaceScan,
                      icon: const Icon(Icons.face_retouching_natural_rounded),
                      label: const Text('Redo 1:1 Face Bio Scan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
              ],
              if (isApproved) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _proceedToPasadaNorte,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Proceed to PasadaNorte'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentEmerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              TextButton(
                onPressed: _switchAccount,
                child: Text(
                  'Use a different phone number',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
