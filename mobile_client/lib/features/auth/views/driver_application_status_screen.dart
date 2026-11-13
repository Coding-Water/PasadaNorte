import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/session_cache_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/system_notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../driver/views/driver_map_duty_screen.dart';
import '../../fare/services/fare_calculator_service.dart';
import '../models/user_model.dart';
import 'face_scan_screen.dart';
import 'phone_input_screen.dart';

// NOTIFICATION CHECKLIST:
// [x] Native Android Notification Center alerts (Approved / Resubmission / Rejected)
// [ ] TODO: Add SMS notification later for Approved, Resubmission, and Rejected decisions

class DriverApplicationStatusScreen extends StatefulWidget {
  final String phoneNumber;
  final String fullName;

  const DriverApplicationStatusScreen({
    super.key,
    required this.phoneNumber,
    required this.fullName,
  });

  @override
  State<DriverApplicationStatusScreen> createState() =>
      _DriverApplicationStatusScreenState();
}

class _DriverApplicationStatusScreenState
    extends State<DriverApplicationStatusScreen> {
  final ImagePicker _picker = ImagePicker();
  StreamSubscription<List<Map<String, dynamic>>>? _statusSubscription;
  Timer? _pollTimer;

  String _status = 'submitted';
  String _adminNotes =
      'Your documents are currently being reviewed by Laoag City MINC / TODA administrators.';
  bool _isRefreshing = false;
  bool _isResubmitting = false;
  String? _lastNotifiedStatus;

  final Map<String, String> _replacementFiles = {};

  static const Map<String, String> _resubmittableFields = {
    'license_photo_url': "Professional Driver's License",
    'profile_photo_url': 'Selfie / Profile Photo',
    'nbi_clearance_url': 'NBI Clearance',
    'police_or_barangay_clearance_url': 'Barangay or Police Clearance',
    'fit_to_work_cert_url': 'Fit-to-Work Medical Certificate',
    'or_photo_url': 'LTO Official Receipt (OR)',
    'cr_photo_url': 'LTO Certificate of Registration (CR)',
    'owner_authorization_letter_url': 'Owner Authorization Letter',
    'owner_id_photo_url': 'Owner Valid ID',
    'vehicle_front_photo_url': 'Tricycle Front View',
    'vehicle_back_photo_url': 'Tricycle Back View',
    'vehicle_left_photo_url': 'Tricycle Left Side',
    'vehicle_right_photo_url': 'Tricycle Right Side',
  };

  bool get _needsFaceScanRedo {
    final lower = _adminNotes.toLowerCase();
    return lower.contains('face bio scan') ||
        lower.contains('face scan') ||
        lower.contains('bioscan');
  }

  List<MapEntry<String, String>> get _flaggedFieldsToShow {
    final lowerNotes = _adminNotes.toLowerCase();
    final matched = _resubmittableFields.entries.where((entry) {
      final label = entry.value.toLowerCase();
      if (lowerNotes.contains(label)) return true;
      if (entry.key == 'police_or_barangay_clearance_url' &&
          (lowerNotes.contains('barangay') || lowerNotes.contains('police'))) {
        return true;
      }
      if (entry.key == 'profile_photo_url' && lowerNotes.contains('selfie')) {
        return true;
      }
      if (entry.key == 'vehicle_front_photo_url' &&
          lowerNotes.contains('front view')) {
        return true;
      }
      if (entry.key == 'vehicle_back_photo_url' &&
          lowerNotes.contains('back view')) {
        return true;
      }
      if (entry.key == 'vehicle_left_photo_url' &&
          lowerNotes.contains('left side')) {
        return true;
      }
      if (entry.key == 'vehicle_right_photo_url' &&
          lowerNotes.contains('right side')) {
        return true;
      }
      return false;
    }).toList();

    if (matched.isNotEmpty || _needsFaceScanRedo) {
      return matched;
    }
    return _resubmittableFields.entries.toList();
  }

  @override
  void initState() {
    super.initState();
    unawaited(
      SessionCacheService.saveDriverSession(
        phoneNumber: widget.phoneNumber,
        fullName: widget.fullName,
        isPendingReview: true,
      ),
    );
    _loadInitialStatus();
    _listenToApplicationStatus();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialStatus() async {
    setState(() => _isRefreshing = true);
    final row =
        await SupabaseService.getDriverApplicationByPhone(widget.phoneNumber);
    if (!mounted) return;
    if (row != null) {
      _applyStatusUpdate(row);
    }
    setState(() => _isRefreshing = false);
  }

  void _listenToApplicationStatus() {
    final client = SupabaseService.client;
    if (client == null) return;
    try {
      _statusSubscription = client
          .from('driver_applications')
          .stream(primaryKey: ['id'])
          .eq('phone_number', widget.phoneNumber)
          .listen((rows) {
            if (!mounted || rows.isEmpty) return;
            _applyStatusUpdate(rows.first);
          });
    } catch (_) {}

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final row =
          await SupabaseService.getDriverApplicationByPhone(widget.phoneNumber);
      if (!mounted || row == null) return;
      _applyStatusUpdate(row);
    });
  }

  void _applyStatusUpdate(Map<String, dynamic> row) {
    final nextStatus = (row['application_status'] ?? 'submitted').toString();
    final nextNotes = (row['admin_notes'] ?? '').toString().trim();

    setState(() {
      _status = nextStatus;
      if (nextNotes.isNotEmpty) {
        _adminNotes = nextNotes;
      }
    });

    if (_lastNotifiedStatus == nextStatus) return;

    if (nextStatus == 'approved') {
      _lastNotifiedStatus = nextStatus;
      SystemNotificationService.showDriverApplicationNotification(
        title: 'Driver Application Approved!',
        body: _adminNotes.isNotEmpty
            ? _adminNotes
            : 'Your PasadaNorte driver documents passed MINC review. You may now go on duty.',
      );
    } else if (nextStatus == 'resubmission_requested') {
      _lastNotifiedStatus = nextStatus;
      SystemNotificationService.showDriverApplicationNotification(
        title: 'Documents Need Resubmission',
        body: _adminNotes.isNotEmpty
            ? _adminNotes
            : 'Please re-upload the flagged documents to continue your driver application.',
      );
    } else if (nextStatus == 'rejected') {
      _lastNotifiedStatus = nextStatus;
      SystemNotificationService.showDriverApplicationNotification(
        title: 'Driver Application Rejected',
        body: _adminNotes.isNotEmpty
            ? _adminNotes
            : 'Your driver application was rejected during MINC compliance review.',
      );
    }
  }

  Future<void> _pickReplacementImage(
    String columnKey,
    String docLabel,
    ImageSource source,
  ) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (file != null && mounted) {
        setState(() => _replacementFiles[columnKey] = file.path);
      }
    } catch (_) {}
  }

  Future<void> _pickReplacementFile(String columnKey, String docLabel) async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.any);
      if (result.isNotEmpty && mounted) {
        final picked = result.first;
        setState(() {
          _replacementFiles[columnKey] = picked.path ?? picked.name;
        });
      }
    } catch (_) {}
  }

  Future<void> _submitResubmission() async {
    if (_replacementFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please attach at least one updated file to resend.'),
        ),
      );
      return;
    }

    setState(() => _isResubmitting = true);
    final ok = await SupabaseService.resubmitDriverDocuments(
      phoneNumber: widget.phoneNumber,
      updatedLocalFilesByColumn: _replacementFiles,
    );
    if (!mounted) return;

    setState(() {
      _isResubmitting = false;
      if (ok) {
        _status = 'submitted';
        _adminNotes =
            'Updated documents submitted. Your application is back under 24-hour MINC review.';
        _replacementFiles.clear();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Updated documents sent for MINC review!'
              : 'Could not resend documents. Please check your connection.',
        ),
        backgroundColor: ok ? AppTheme.accentEmerald : AppTheme.cancelRed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isApproved = _status == 'approved';
    final bool isResubmission = _status == 'resubmission_requested';
    final bool isRejected = _status == 'rejected';
    final bool isUnderReview = !isApproved && !isResubmission && !isRejected;

    final IconData statusIcon = isApproved
        ? Icons.verified_rounded
        : isResubmission
            ? Icons.upload_file_rounded
            : isRejected
                ? Icons.block_rounded
                : Icons.hourglass_top_rounded;

    final Color statusColor = isApproved
        ? AppTheme.accentEmerald
        : isResubmission
            ? Colors.amber.shade800
            : isRejected
                ? AppTheme.cancelRed
                : AppTheme.primarySlate;

    final String heading = isApproved
        ? 'Application Approved!'
        : isResubmission
            ? 'Document Resubmission Requested'
            : isRejected
                ? 'Application Rejected'
                : 'Your documents are currently being reviewed';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Application Review Status',
          style: TextStyle(
            color: AppTheme.primarySlate,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _isRefreshing ? null : _loadInitialStatus,
            tooltip: 'Refresh Status',
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, color: AppTheme.primarySlate),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    if (isUnderReview)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/review_hourglass.jpg',
                          width: 156,
                          height: 98,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(statusIcon, color: statusColor, size: 36),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      heading,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primarySlate,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (isUnderReview) ...[
                      const Text(
                        'Estimated review time: within 24 hours.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'You will receive a notification on your phone once Laoag City MINC / TODA approves your documents or requests clearer files.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: Colors.black54,
                        ),
                      ),
                    ] else ...[
                      Text(
                        _adminNotes,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isApproved) ...[
                const SizedBox(height: 22),
                ElevatedButton.icon(
                  onPressed: () async {
                    await SessionCacheService.saveDriverSession(
                      phoneNumber: widget.phoneNumber,
                      fullName: widget.fullName,
                      isPendingReview: false,
                    );
                    if (!context.mounted) return;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DriverMapDutyScreen(fullName: widget.fullName),
                      ),
                    );
                  },
                  icon: const Icon(Icons.two_wheeler_rounded),
                  label: const Text('Proceed to Driver Duty Map'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentEmerald,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
              if (isResubmission) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Admin Objection / Reason:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _adminNotes,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_needsFaceScanRedo) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.accentEmerald),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '1:1 Face Bio Scan Required',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primarySlate,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Please redo your live 1:1 face verification scan so MINC can complete your identity check.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.black87,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FaceScanScreen(
                                  phoneNumber: widget.phoneNumber,
                                  fullName: widget.fullName,
                                  role: UserRole.driver,
                                  passengerCategory: PassengerCategory.regular,
                                  idType: "Professional Driver's License",
                                  idPhotoPath: '',
                                  isResubmissionRedo: true,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.face_retouching_natural_rounded, size: 18),
                          label: const Text('Redo 1:1 Face Bio Scan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentEmerald,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_flaggedFieldsToShow.isNotEmpty) ...[
                  const Text(
                    'Upload Updated Files to Resend',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primarySlate,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._flaggedFieldsToShow.map((entry) {
                  final selectedPath = _replacementFiles[entry.key];
                  final fileName =
                      selectedPath?.split(RegExp(r'[/\\]')).last;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: fileName != null
                            ? AppTheme.accentEmerald
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.value,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        if (fileName != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Ready to send: $fileName',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.accentEmeraldDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _pickReplacementImage(
                                entry.key,
                                entry.value,
                                ImageSource.camera,
                              ),
                              icon: const Icon(Icons.camera_alt_rounded, size: 15),
                              label: const Text('Camera', style: TextStyle(fontSize: 12)),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _pickReplacementImage(
                                entry.key,
                                entry.value,
                                ImageSource.gallery,
                              ),
                              icon: const Icon(Icons.photo_library_rounded, size: 15),
                              label: const Text('Gallery', style: TextStyle(fontSize: 12)),
                            ),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _pickReplacementFile(entry.key, entry.value),
                              icon: const Icon(Icons.upload_file_rounded, size: 15),
                              label: const Text('Files', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _isResubmitting ? null : _submitResubmission,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentEmerald,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isResubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Resubmit Documents',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ],
              ],
              if (isRejected) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: const Text(
                    'Your submission was flagged as suspicious or ineligible during MINC compliance verification. Please contact the Laoag City MINC / TODA office for assistance.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Center(
                child: TextButton(
                  onPressed: () async {
                    await SessionCacheService.clearSession();
                    if (!context.mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const PhoneInputScreen(initialIsRegisterMode: false),
                      ),
                      (route) => false,
                    );
                  },
                  child: const Text(
                    'Use a different account',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
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
