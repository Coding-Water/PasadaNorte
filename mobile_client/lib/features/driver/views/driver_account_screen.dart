import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/driver_stats_service.dart';
import '../../../core/services/session_cache_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/views/welcome_onboarding_screen.dart';
import '../../legal/views/privacy_policy_screen.dart';
import '../../legal/views/terms_of_service_screen.dart';

class DriverAccountScreen extends StatefulWidget {
  final String fullName;

  const DriverAccountScreen({
    super.key,
    required this.fullName,
  });

  @override
  State<DriverAccountScreen> createState() => _DriverAccountScreenState();
}

class _DriverAccountScreenState extends State<DriverAccountScreen> {
  String _photoPath = '';
  String _phoneNumber = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final session = await SessionCacheService.getSavedSession();
    final details = await SessionCacheService.getPassengerProfileDetails();
    if (!mounted) return;
    setState(() {
      _phoneNumber = session?.phoneNumber ?? details['phone'] ?? '';
      _photoPath = details['photoPath'] ?? '';
    });
  }

  Widget _buildAvatar({double radius = 28}) {
    final initial = widget.fullName.trim().isNotEmpty
        ? widget.fullName.trim().substring(0, 1).toUpperCase()
        : 'D';

    if (_photoPath.isNotEmpty) {
      final file = File(_photoPath);
      if (file.existsSync()) {
        return CircleAvatar(
          radius: radius,
          backgroundColor: const Color(0xFFDCFCE7),
          backgroundImage: FileImage(file),
        );
      }
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFDCFCE7),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w800,
          color: AppTheme.accentEmeraldDark,
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;
      await SessionCacheService.updateProfilePhoto(picked.path);
      if (!mounted) return;
      setState(() => _photoPath = picked.path);
    } catch (_) {}
  }

  Future<void> _showLogoutSheet() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Logout',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFFDC2626),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Are you sure you want to sign out of your driver account?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE8F8EF),
                        foregroundColor: AppTheme.accentEmerald,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentEmerald,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'Yes, Logout',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      unawaited(SessionCacheService.clearSession());
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeOnboardingScreen()),
        (route) => false,
      );
    }
  }

  Widget _buildDocumentRenewalAlertCard(Map<String, dynamic> alert) {
    final isOnReview = alert['renewal_status'] == 'on_review';
    final docsRaw = (alert['expired_docs'] as List?) ?? const [];
    final docLabels = docsRaw.isEmpty
        ? ["Professional Driver's License", 'LTO OR/CR']
        : docsRaw
            .map((d) => (d is Map ? d['label'] : d).toString())
            .toList();
    final graceUntil = (alert['grace_until'] ?? '').toString().split('T').first;
    final submittedFiles = alert['renewed_files'] is Map
        ? Map<String, dynamic>.from(alert['renewed_files'] as Map)
        : const <String, dynamic>{};

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOnReview ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOnReview ? const Color(0xFFF59E0B) : const Color(0xFFFCA5A5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isOnReview
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isOnReview
                      ? Icons.hourglass_top_rounded
                      : Icons.warning_amber_rounded,
                  color: isOnReview
                      ? const Color(0xFFD97706)
                      : const Color(0xFFDC2626),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isOnReview
                      ? 'On Review — Renewed Documents Submitted'
                      : 'Expired Documents — Renewal Required',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: isOnReview
                        ? const Color(0xFF92400E)
                        : const Color(0xFF991B1B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isOnReview
                ? 'Your renewed documents have been sent and are currently On Review by MINC Admin:'
                : 'MINC Admin notified you that the following document(s) are expired or due for renewal:',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 8),
          ...docLabels.map(
            (label) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    isOnReview
                        ? Icons.check_circle_outline_rounded
                        : Icons.error_outline_rounded,
                    size: 15,
                    color: isOnReview
                        ? const Color(0xFFD97706)
                        : const Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isOnReview && submittedFiles[label] != null
                          ? '$label (${submittedFiles[label]})'
                          : label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: isOnReview
                            ? const Color(0xFF78350F)
                            : const Color(0xFF7F1D1D),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isOnReview && graceUntil.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Grace Period Deadline: $graceUntil',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Color(0xFFB45309),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            isOnReview
                ? 'Waiting for MINC Admin approval. Once approved, you can accept passengers again.'
                : 'You cannot go online or accept passengers until you resend your renewed files.',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isOnReview
                  ? const Color(0xFFB45309)
                  : const Color(0xFFB91C1C),
            ),
          ),
          const SizedBox(height: 12),
          if (isOnReview)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_top_rounded, size: 18, color: Color(0xFFB45309)),
                  SizedBox(width: 8),
                  Text(
                    'On Review • Waiting for MINC Admin',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _showResendRenewedFilesSheet(docLabels),
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text(
                  'Click here to resend files',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showResendRenewedFilesSheet(List<String> docLabels) async {
    final Map<String, String> attachedFiles = {};
    bool isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final allAttached = docLabels.every((d) => attachedFiles.containsKey(d));
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resend Renewed Documents',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upload updated copies of your expired documents to end your grace period and resume passenger trips.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 14),
                ...docLabels.map((label) {
                  final fileName = attachedFiles[label];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: fileName != null
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: fileName != null
                            ? const Color(0xFF6EE7B7)
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          fileName != null
                              ? Icons.check_circle_rounded
                              : Icons.description_outlined,
                          color: fileName != null
                              ? AppTheme.accentEmeraldDark
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                fileName ?? 'No renewed file selected',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: fileName != null
                                      ? AppTheme.accentEmeraldDark
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Camera',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.camera_alt_rounded, size: 20, color: AppTheme.accentEmeraldDark),
                              onPressed: () async {
                                try {
                                  final photo = await ImagePicker().pickImage(
                                    source: ImageSource.camera,
                                    imageQuality: 85,
                                  );
                                  if (photo != null) {
                                    setSheetState(() {
                                      attachedFiles[label] = photo.name;
                                    });
                                  }
                                } catch (_) {}
                              },
                            ),
                            IconButton(
                              tooltip: 'Image Gallery',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.photo_library_rounded, size: 20, color: AppTheme.accentEmeraldDark),
                              onPressed: () async {
                                try {
                                  final photo = await ImagePicker().pickImage(
                                    source: ImageSource.gallery,
                                    imageQuality: 85,
                                  );
                                  if (photo != null) {
                                    setSheetState(() {
                                      attachedFiles[label] = photo.name;
                                    });
                                  }
                                } catch (_) {}
                              },
                            ),
                            IconButton(
                              tooltip: 'Choose File',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.upload_file_rounded, size: 20, color: AppTheme.accentEmeraldDark),
                              onPressed: () async {
                                try {
                                  final picked = await FilePicker.pickFiles(
                                    type: FileType.custom,
                                    allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
                                  );
                                  if (picked.isNotEmpty) {
                                    setSheetState(() {
                                      attachedFiles[label] = picked.first.name;
                                    });
                                  }
                                } catch (_) {}
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentEmerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: (!allAttached || isSubmitting)
                        ? null
                        : () async {
                            setSheetState(() => isSubmitting = true);
                            await SupabaseService.submitRenewedDriverDocuments(
                              phoneNumber: _phoneNumber,
                              driverName: widget.fullName,
                              renewedFileNames: attachedFiles,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Color(0xFFD97706),
                                  content: Text(
                                    'Renewed documents submitted! Status is now On Review — waiting for MINC Admin approval.',
                                  ),
                                ),
                              );
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Submit Renewed Files',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openDriverDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _DriverDetailsScreen(
          fullName: widget.fullName,
          phoneNumber: _phoneNumber,
          avatar: _buildAvatar(radius: 42),
          onChangePhoto: _pickPhoto,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todaSummary = DriverStatsService.bodyNumber == 'Pending'
        ? DriverStatsService.todaAssociation
        : '${DriverStatsService.todaAssociation} • ${DriverStatsService.bodyNumber}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          'Account',
          style: TextStyle(
            color: AppTheme.primarySlate,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: SupabaseService.activeRenewalAlertNotifier,
            builder: (context, alert, _) {
              if (alert == null) return const SizedBox.shrink();
              return _buildDocumentRenewalAlertCard(alert);
            },
          ),
          // Profile Card
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _openDriverDetails,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildAvatar(radius: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primarySlate,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            todaSummary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accentEmerald,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey.shade500,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Menu Card
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _menuTile(
                  icon: Icons.verified_user_outlined,
                  title: 'TODA & Franchise Info',
                  onTap: _openDriverDetails,
                ),
                _divider(),
                _menuTile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const _DriverNotificationsScreen(),
                    ),
                  ),
                ),
                _divider(),
                _menuTile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Payout Methods',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const _DriverPayoutMethodsScreen(),
                    ),
                  ),
                ),
                _divider(),
                _menuTile(
                  icon: Icons.security_rounded,
                  title: 'Account & Security',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const _DriverSecurityScreen(),
                    ),
                  ),
                ),
                _divider(),
                _menuTile(
                  icon: Icons.help_outline_rounded,
                  title: 'Help & Support',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const _DriverHelpScreen(),
                    ),
                  ),
                ),
                _divider(),
                ListTile(
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFDC2626),
                  ),
                  title: const Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  onTap: _showLogoutSheet,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(
        height: 1,
        indent: 56,
        color: Colors.grey.shade100,
      );

  Widget _menuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primarySlate),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: AppTheme.primarySlate,
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
      onTap: onTap,
    );
  }
}

class _DriverDetailsScreen extends StatelessWidget {
  final String fullName;
  final String phoneNumber;
  final Widget avatar;
  final Future<void> Function() onChangePhoto;

  const _DriverDetailsScreen({
    required this.fullName,
    required this.phoneNumber,
    required this.avatar,
    required this.onChangePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Driver & Franchise Details',
          style: TextStyle(
            color: AppTheme.primarySlate,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                avatar,
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: onChangePhoto,
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Change Profile Photo'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                _row('Full Name', fullName),
                const Divider(height: 20),
                _row('Phone Number', phoneNumber.isEmpty ? 'Verified' : phoneNumber),
                const Divider(height: 20),
                _row('TODA Terminal', DriverStatsService.todaAssociation),
                const Divider(height: 20),
                _row('Assigned Pila / Body #', DriverStatsService.bodyNumber),
                const Divider(height: 20),
                _row('LTO Plate Number', DriverStatsService.plateNumber),
                const Divider(height: 20),
                _row('MINC Franchise', DriverStatsService.mincFranchiseNumber),
                const Divider(height: 20),
                _row('Inspection Status', DriverStatsService.lastInspectionStatus),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.primarySlate,
            ),
          ),
        ),
      ],
    );
  }
}

class _DriverNotificationsScreen extends StatefulWidget {
  const _DriverNotificationsScreen();

  @override
  State<_DriverNotificationsScreen> createState() =>
      _DriverNotificationsScreenState();
}

class _DriverNotificationsScreenState
    extends State<_DriverNotificationsScreen> {
  final Map<String, bool> _prefs = {
    'Ride Dispatch Alerts': true,
    'Safety & SOS Alerts': true,
    'TODA Queue Updates': true,
    'Important Announcements': true,
    'App Updates': true,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (final key in _prefs.keys) {
        _prefs[key] = sp.getBool('pn_drv_notif_$key') ?? _prefs[key]!;
      }
    });
  }

  Future<void> _toggle(String key, bool val) async {
    setState(() => _prefs[key] = val);
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('pn_drv_notif_$key', val);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: AppTheme.primarySlate,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: _prefs.entries
                  .map(
                    (e) => SwitchListTile(
                      title: Text(
                        e.key,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      value: e.value,
                      activeTrackColor: AppTheme.accentEmerald,
                      onChanged: (v) => _toggle(e.key, v),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverPayoutMethodsScreen extends StatelessWidget {
  const _DriverPayoutMethodsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Payout Methods',
          style: TextStyle(
            color: AppTheme.primarySlate,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: const Column(
              children: [
                ListTile(
                  leading: Icon(Icons.payments_outlined, color: AppTheme.accentEmerald),
                  title: Text('Cash Fare Collection', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('Active for all standard and PasaDeliver trips'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.account_balance_wallet_outlined, color: Colors.blue),
                  title: Text('GCash / Maya E-Wallet', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('E-wallet linking coming soon'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverSecurityScreen extends StatelessWidget {
  const _DriverSecurityScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Account & Security',
          style: TextStyle(
            color: AppTheme.primarySlate,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
            title: const Text(
              'Delete Account',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFFDC2626),
              ),
            ),
            subtitle: const Text('Permanently remove your driver account'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Account?'),
                  content: const Text(
                    'This will remove your local driver session and request account deletion.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Color(0xFFDC2626)),
                      ),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                unawaited(SessionCacheService.clearSession());
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const WelcomeOnboardingScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ),
      ),
    );
  }
}

class _DriverHelpScreen extends StatelessWidget {
  const _DriverHelpScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Help & Support',
          style: TextStyle(
            color: AppTheme.primarySlate,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Terms of Service'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
