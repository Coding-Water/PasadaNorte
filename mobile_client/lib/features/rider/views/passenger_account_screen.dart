import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/session_cache_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/views/welcome_onboarding_screen.dart';
import '../../fare/services/fare_calculator_service.dart';
import '../../legal/views/privacy_policy_screen.dart';
import '../../legal/views/terms_of_service_screen.dart';
import 'saved_addresses_screen.dart';

class PassengerAccountScreen extends StatefulWidget {
  final String fullName;
  final PassengerCategory lockedCategory;
  final String verifiedIdType;

  const PassengerAccountScreen({
    super.key,
    required this.fullName,
    required this.lockedCategory,
    required this.verifiedIdType,
  });

  @override
  State<PassengerAccountScreen> createState() => _PassengerAccountScreenState();
}

class _PassengerAccountScreenState extends State<PassengerAccountScreen> {
  String _photoPath = '';

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    final details = await SessionCacheService.getPassengerProfileDetails();
    if (!mounted) return;
    setState(() {
      _photoPath = details['photoPath'] ?? '';
    });
  }

  Widget _buildAvatar({double radius = 28}) {
    final initial = widget.fullName.trim().isNotEmpty
        ? widget.fullName.trim().substring(0, 1).toUpperCase()
        : 'P';

    if (_photoPath.isNotEmpty) {
      if (_photoPath.startsWith('assets/')) {
        return CircleAvatar(
          radius: radius,
          backgroundColor: const Color(0xFFDCFCE7),
          backgroundImage: AssetImage(_photoPath),
        );
      }
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

  Future<void> _showLogoutSheet() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFEF4444),
                ),
              ),
              const SizedBox(height: 12),
              Divider(color: Colors.grey.shade200, height: 1),
              const SizedBox(height: 18),
              const Text(
                'Sure you want to log out?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primarySlate,
                ),
              ),
              const SizedBox(height: 20),
              Divider(color: Colors.grey.shade200, height: 1),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFE8F8EF),
                          foregroundColor: AppTheme.accentEmerald,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.w800),
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
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    unawaited(SessionCacheService.clearSession());
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeOnboardingScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
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
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: AppTheme.primarySlate,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: Column(
          children: [
            // User Profile Card (Tap to view read-only registration details & change photo)
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _PassengerProfileScreen(
                      fullName: widget.fullName,
                      lockedCategory: widget.lockedCategory,
                      verifiedIdType: widget.verifiedIdType,
                    ),
                  ),
                );
                _loadPhoto();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x060F172A),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
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
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F8EF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Verified ${widget.lockedCategory.name.toUpperCase()}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.accentEmerald,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: AppTheme.primarySlate,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Account Menu Card
            Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0xFFF1F5F9)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.location_on_outlined,
                    title: 'Saved Addresses',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SavedAddressesScreen(
                          fullName: widget.fullName,
                          lockedCategory: widget.lockedCategory,
                          showBackButton: true,
                        ),
                      ),
                    ),
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const _NotificationsSettingsScreen(),
                      ),
                    ),
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.credit_card_outlined,
                    title: 'Payment Methods',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const _PaymentMethodsScreen(),
                      ),
                    ),
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.verified_user_outlined,
                    title: 'Account & Security',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const _AccountSecurityScreen(),
                      ),
                    ),
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.description_outlined,
                    title: 'Help & Support',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const _HelpSupportScreen(),
                      ),
                    ),
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.logout_rounded,
                    title: 'Logout',
                    isDestructive: true,
                    showChevron: false,
                    onTap: _showLogoutSheet,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'PasadaNorte Laoag City • v1.0.0+1',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() => const Divider(height: 1, indent: 52, endIndent: 16);

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
    bool showChevron = true,
  }) {
    final color = isDestructive ? const Color(0xFFEF4444) : AppTheme.primarySlate;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      trailing: showChevron
          ? const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15,
              color: AppTheme.primarySlate,
            )
          : null,
      onTap: onTap,
    );
  }
}

// =============================================================================
// 1. MY PROFILE (Read-Only Registration Details; Only Profile Photo Editable)
// =============================================================================
class _PassengerProfileScreen extends StatefulWidget {
  final String fullName;
  final PassengerCategory lockedCategory;
  final String verifiedIdType;

  const _PassengerProfileScreen({
    required this.fullName,
    required this.lockedCategory,
    required this.verifiedIdType,
  });

  @override
  State<_PassengerProfileScreen> createState() =>
      _PassengerProfileScreenState();
}

class _PassengerProfileScreenState extends State<_PassengerProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  Map<String, String> _details = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final cached = await SessionCacheService.getPassengerProfileDetails();
    final session = await SessionCacheService.getSavedSession();

    final parts = widget.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    final fallbackFirst = parts.isNotEmpty ? parts.first : '';
    final fallbackLast = parts.length > 1 ? parts.last : '';
    final fallbackMiddle =
        parts.length > 2 ? parts.sublist(1, parts.length - 1).join(' ') : '';

    if (!mounted) return;
    setState(() {
      _details = {
        'firstName': (cached['firstName']?.isNotEmpty ?? false)
            ? cached['firstName']!
            : fallbackFirst,
        'middleName': cached['middleName']?.isNotEmpty == true
            ? cached['middleName']!
            : fallbackMiddle,
        'lastName': (cached['lastName']?.isNotEmpty ?? false)
            ? cached['lastName']!
            : fallbackLast,
        'gender': cached['gender']?.isNotEmpty == true
            ? cached['gender']!
            : 'Not specified',
        'dob': cached['dob']?.isNotEmpty == true
            ? cached['dob']!
            : 'Verified on ID',
        'phone': (cached['phone']?.isNotEmpty ?? false)
            ? cached['phone']!
            : (session?.phoneNumber ?? 'Registered Mobile'),
        'photoPath': cached['photoPath'] ?? '',
      };
      _isLoading = false;
    });
  }

  Future<void> _changeProfilePhoto(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;
      await SessionCacheService.updateProfilePhoto(file.path);
      if (!mounted) return;
      setState(() {
        _details['photoPath'] = file.path;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture updated.'),
          backgroundColor: AppTheme.accentEmerald,
        ),
      );
    } catch (_) {}
  }

  void _showPhotoOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Change Profile Picture',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primarySlate,
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: AppTheme.accentEmerald,
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _changeProfilePhoto(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_outlined,
                  color: AppTheme.accentEmerald,
                ),
                title: const Text(
                  'Take a Photo',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _changeProfilePhoto(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPreview() {
    final photoPath = _details['photoPath'] ?? '';
    final initial = widget.fullName.trim().isNotEmpty
        ? widget.fullName.trim().substring(0, 1).toUpperCase()
        : 'P';

    ImageProvider? imageProvider;
    if (photoPath.isNotEmpty) {
      if (photoPath.startsWith('assets/')) {
        imageProvider = AssetImage(photoPath);
      } else {
        final file = File(photoPath);
        if (file.existsSync()) {
          imageProvider = FileImage(file);
        }
      }
    }

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: const Color(0xFFDCFCE7),
          backgroundImage: imageProvider,
          child: imageProvider == null
              ? Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.accentEmeraldDark,
                  ),
                )
              : null,
        ),
        GestureDetector(
          onTap: _showPhotoOptions,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accentEmerald,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.primarySlate,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: AppTheme.primarySlate,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accentEmerald),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _showPhotoOptions,
                    child: _buildAvatarPreview(),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _showPhotoOptions,
                    child: const Text(
                      'Change Profile Picture',
                      style: TextStyle(
                        color: AppTheme.accentEmerald,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 16,
                          color: Color(0xFF475569),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Personal details from your registration form are locked for ID & fare verification. Only your profile picture can be changed.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _readOnlyField('Last Name', _details['lastName'] ?? ''),
                        _readOnlyField('First Name', _details['firstName'] ?? ''),
                        _readOnlyField(
                          'Middle Name',
                          (_details['middleName'] ?? '').isEmpty
                              ? '—'
                              : _details['middleName']!,
                        ),
                        _readOnlyField('Gender', _details['gender'] ?? '—'),
                        _readOnlyField('Date of Birth', _details['dob'] ?? '—'),
                        _readOnlyField('Mobile Number', _details['phone'] ?? '—'),
                        _readOnlyField(
                          'Fare Tier',
                          widget.lockedCategory.name.toUpperCase(),
                        ),
                        _readOnlyField(
                          'Verified ID Type',
                          widget.verifiedIdType,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _readOnlyField(String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.primarySlate,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 2. NOTIFICATIONS SETTINGS (7 Kept Toggles)
// =============================================================================
class _NotificationsSettingsScreen extends StatefulWidget {
  const _NotificationsSettingsScreen();

  @override
  State<_NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<_NotificationsSettingsScreen> {
  static const String _prefsKey = 'pn_notif_prefs_v1';

  final Map<String, bool> _toggles = {
    'General Updates': true,
    'Safety and Security Alerts': true,
    'Account Notifications': false,
    'Ride Status Updates': true,
    'App Updates': true,
    'Survey and Feedback Requests': false,
    'Important Announcements': true,
  };

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        if (!mounted) return;
        setState(() {
          for (final key in _toggles.keys) {
            if (decoded.containsKey(key)) {
              _toggles[key] = decoded[key] == true;
            }
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _savePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_toggles));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final keys = _toggles.keys.toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.primarySlate,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: AppTheme.primarySlate,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFF1F5F9)),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: keys.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
            itemBuilder: (_, index) {
              final label = keys[index];
              final value = _toggles[label] ?? false;
              return SwitchListTile.adaptive(
                value: value,
                activeTrackColor: AppTheme.accentEmerald,
                title: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primarySlate,
                  ),
                ),
                onChanged: (next) {
                  setState(() => _toggles[label] = next);
                  _savePrefs();
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 3. PAYMENT METHODS (Link E-Wallets UI — No Gateway Code Yet)
// =============================================================================
class _PaymentMethodsScreen extends StatefulWidget {
  const _PaymentMethodsScreen();

  @override
  State<_PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<_PaymentMethodsScreen> {
  static const String _prefsKey = 'pn_linked_ewallets_v1';
  List<Map<String, String>> _wallets = [];

  @override
  void initState() {
    super.initState();
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefsKey) ?? const [];
      if (!mounted) return;
      setState(() {
        _wallets = raw
            .map((e) => Map<String, String>.from(jsonDecode(e) as Map))
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _persistWallets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _prefsKey,
        _wallets.map((e) => jsonEncode(e)).toList(),
      );
    } catch (_) {}
  }

  Future<void> _openAddWalletSheet() async {
    String selectedProvider = 'GCash';
    final accountCtrl = TextEditingController();

    final added = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'Link E-Wallet',
                  style: TextStyle(
                    fontSize: 17.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primarySlate,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Select E-Wallet Provider',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primarySlate,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['GCash', 'Maya', 'GrabPay', 'ShopeePay'].map((p) {
                  final active = selectedProvider == p;
                  return ChoiceChip(
                    label: Text(p),
                    selected: active,
                    selectedColor: AppTheme.accentEmerald,
                    labelStyle: TextStyle(
                      color: active ? Colors.white : AppTheme.primarySlate,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (_) => setSheetState(() => selectedProvider = p),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: accountCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Mobile Number / Account',
                  hintText: '09XX XXX XXXX',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFE8F8EF),
                          foregroundColor: AppTheme.accentEmerald,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(23),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () {
                          final numText = accountCtrl.text.trim();
                          if (numText.isEmpty) return;
                          Navigator.pop(ctx, {
                            'provider': selectedProvider,
                            'account': numText,
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentEmerald,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(23),
                          ),
                        ),
                        child: const Text(
                          'Link Wallet',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (added == null || !mounted) return;
    setState(() => _wallets.add(added));
    await _persistWallets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.primarySlate,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Payment Methods',
          style: TextStyle(
            color: AppTheme.primarySlate,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: const ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: Color(0xFFE8F8EF),
                      child: Icon(
                        Icons.payments_outlined,
                        color: AppTheme.accentEmerald,
                      ),
                    ),
                    title: Text(
                      'Cash',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primarySlate,
                      ),
                    ),
                    subtitle: Text(
                      'Default payment method for Laoag TODA rides',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Linked E-Wallets',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primarySlate,
                  ),
                ),
                const SizedBox(height: 8),
                if (_wallets.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      'No e-wallets linked yet. Tap "+ Add E-Wallet" below to link GCash, Maya, or another e-wallet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  )
                else
                  ..._wallets.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final w = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFFE8F8EF),
                            child: Icon(
                              Icons.account_balance_wallet_outlined,
                              color: AppTheme.accentEmerald,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  w['provider'] ?? 'E-Wallet',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                    color: AppTheme.primarySlate,
                                  ),
                                ),
                                Text(
                                  w['account'] ?? '',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Color(0xFFEF4444),
                            ),
                            onPressed: () async {
                              setState(() => _wallets.removeAt(idx));
                              await _persistWallets();
                            },
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _openAddWalletSheet,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(
                    'Add E-Wallet',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentEmerald,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 4. ACCOUNT & SECURITY (Only Delete Account)
// =============================================================================
class _AccountSecurityScreen extends StatelessWidget {
  const _AccountSecurityScreen();

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Delete Account',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFEF4444),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'This will permanently remove your PasadaNorte passenger account and local data.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppTheme.primarySlate),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFE8F8EF),
                          foregroundColor: AppTheme.accentEmerald,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.w800),
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
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text(
                          'Yes, Delete',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await SessionCacheService.clearSession();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeOnboardingScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.primarySlate,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Account & Security',
          style: TextStyle(
            color: AppTheme.primarySlate,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFF1F5F9)),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 10,
            ),
            title: const Text(
              'Delete Account',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Permanently remove your account and data. Proceed with caution.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
              ),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15,
              color: Color(0xFFEF4444),
            ),
            onTap: () => _confirmDeleteAccount(context),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 5. HELP & SUPPORT (FAQ, Contact Support, Privacy Policy, Terms, Feedback, About)
// =============================================================================
class _HelpSupportScreen extends StatelessWidget {
  const _HelpSupportScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.primarySlate,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Help & Support',
          style: TextStyle(
            color: AppTheme.primarySlate,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFF1F5F9)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _item(
                context,
                'FAQ',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const _FaqScreen()),
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _item(
                context,
                'Contact Support',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const _ContactSupportScreen(),
                  ),
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _item(
                context,
                'Privacy Policy',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _item(
                context,
                'Terms of Service',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TermsOfServiceScreen(),
                  ),
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _item(
                context,
                'Feedback',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const _FeedbackScreen()),
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _item(
                context,
                'About us',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const _AboutUsScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, String title, VoidCallback onTap) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppTheme.primarySlate,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 15,
        color: AppTheme.primarySlate,
      ),
      onTap: onTap,
    );
  }
}

class _FaqScreen extends StatefulWidget {
  const _FaqScreen();

  @override
  State<_FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<_FaqScreen> {
  String _selectedCategory = 'General';
  String _query = '';

  static const List<String> _categories = [
    'General',
    'Account',
    'Services',
    'Ride',
  ];

  static const List<Map<String, String>> _faqs = [
    {
      'category': 'General',
      'q': 'What is PasadaNorte?',
      'a':
          'PasadaNorte is a Laoag City tricycle ride-hailing and TODA dispatch platform built to make daily commuting safer, fairer, and easier to book from your phone.',
    },
    {
      'category': 'General',
      'q': 'How are tricycle fares calculated?',
      'a':
          'Fares follow Laoag City Ordinance No. 2023-005 based on road distance and your verified passenger tier (Regular, Student, or Senior Citizen / PWD).',
    },
    {
      'category': 'Account',
      'q': 'Why can\'t I edit my name or birthday in My Profile?',
      'a':
          'Registration details are locked after ID verification to protect fare-discount integrity and commuter safety. You can update your profile picture anytime.',
    },
    {
      'category': 'Services',
      'q': 'What is the difference between Standard Ride and Special Trip?',
      'a':
          'Standard Ride dispatches the next available TODA unit along normal corridors, while Special Trip books a dedicated tricycle directly to your pinned drop-off.',
    },
    {
      'category': 'Ride',
      'q': 'How do I save frequent destinations like Home or School?',
      'a':
          'Open the Address tab in the bottom bar and tap Add Address to pin any Laoag City location on the map. Saved places appear as quick shortcuts when booking.',
    },
    {
      'category': 'Ride',
      'q': 'Is my ride tracked for safety?',
      'a':
          'Yes. Every active PasadaNorte trip shares live GPS telemetry with the Laoag City MINC & TODA command desk and includes emergency SOS support.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _faqs.where((item) {
      final matchesCat =
          _query.isNotEmpty || item['category'] == _selectedCategory;
      final matchesQ = _query.isEmpty ||
          item['q']!.toLowerCase().contains(_query.toLowerCase()) ||
          item['a']!.toLowerCase().contains(_query.toLowerCase());
      return matchesCat && matchesQ;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.primarySlate,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'FAQ',
          style: TextStyle(
            color: AppTheme.primarySlate,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: InputDecoration(
              hintText: 'Search questions...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final selected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: selected,
                    selectedColor: AppTheme.accentEmerald,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppTheme.primarySlate,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          ...filtered.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ExpansionTile(
                shape: const Border(),
                title: Text(
                  item['q']!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.primarySlate,
                  ),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                children: [
                  Text(
                    item['a']!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ContactSupportScreen extends StatelessWidget {
  const _ContactSupportScreen();

  @override
  Widget build(BuildContext context) {
    final channels = [
      {
        'icon': Icons.headset_mic_outlined,
        'title': 'PasadaNorte Support Desk',
        'subtitle': 'Laoag City TODA & MINC Help Center',
      },
      {
        'icon': Icons.email_outlined,
        'title': 'Email Support',
        'subtitle': 'support@pasadanorte.ph',
      },
      {
        'icon': Icons.local_police_outlined,
        'title': 'Emergency Dispatch Hotline',
        'subtitle': 'Laoag PNP & CDRRMO: (077) 772-0256',
      },
      {
        'icon': Icons.chat_bubble_outline_rounded,
        'title': 'TODA Terminal Assistance',
        'subtitle': 'Available 24/7 at Laoag Central Terminal',
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.primarySlate,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Contact Support',
          style: TextStyle(
            color: AppTheme.primarySlate,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: channels.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, idx) {
          final c = channels[idx];
          return Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(
                c['icon'] as IconData,
                color: AppTheme.accentEmerald,
              ),
              title: Text(
                c['title'] as String,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  color: AppTheme.primarySlate,
                ),
              ),
              subtitle: Text(
                c['subtitle'] as String,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FeedbackScreen extends StatefulWidget {
  const _FeedbackScreen();

  @override
  State<_FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<_FeedbackScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  int _rating = 5;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.primarySlate,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Feedback',
          style: TextStyle(
            color: AppTheme.primarySlate,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share your PasadaNorte experience',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.primarySlate,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: List.generate(5, (i) {
                final star = i + 1;
                return IconButton(
                  icon: Icon(
                    star <= _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: const Color(0xFFF59E0B),
                    size: 32,
                  ),
                  onPressed: () => setState(() => _rating = star),
                );
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _msgCtrl,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Tell us how we can improve tricycle rides in Laoag...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Thank you for your feedback!'),
                      backgroundColor: AppTheme.accentEmerald,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentEmerald,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  'Submit Feedback',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutUsScreen extends StatelessWidget {
  const _AboutUsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.primarySlate,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'About us',
          style: TextStyle(
            color: AppTheme.primarySlate,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PasadaNorte',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primarySlate,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'PasadaNorte is a Laoag City smart paratransit platform designed to connect commuters and licensed TODA tricycle drivers with transparent ordinance-based fares, live GPS tracking, and real-time safety dispatch.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Version 1.0.0+1 • Laoag City, Ilocos Norte',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
