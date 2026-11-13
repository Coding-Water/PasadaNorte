import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../fare/services/fare_calculator_service.dart';
import '../models/user_model.dart';
import 'driver_requirements_checklist_screen.dart';
import 'id_upload_screen.dart';

class UserDetailsInputScreen extends StatefulWidget {
  final String phoneNumber;
  final UserRole role;
  final PassengerCategory passengerCategory;

  const UserDetailsInputScreen({
    super.key,
    required this.phoneNumber,
    required this.role,
    this.passengerCategory = PassengerCategory.regular,
  });

  @override
  State<UserDetailsInputScreen> createState() => _UserDetailsInputScreenState();
}

class _UserDetailsInputScreenState extends State<UserDetailsInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _lastNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _suffixController = TextEditingController();
  final _dobController = TextEditingController();
  late final TextEditingController _phoneController;

  String? _selectedGender;
  DateTime? _selectedDob;

  // Profile picture: user-picked real photo file path
  String? _pickedPhotoPath;
  final ImagePicker _picker = ImagePicker();

  static const List<String> _genderOptions = [
    'Male',
    'Female',
    'Non-Binary',
    'Transgender Man',
    'Transgender Woman',
    'Genderqueer / Genderfluid',
    'Agender',
    'Two-Spirit',
    'Intersex',
    'Prefer not to say',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.phoneNumber);
  }

  @override
  void dispose() {
    _lastNameController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _suffixController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _composeFullName() {
    final parts = <String>[
      _firstNameController.text.trim(),
      if (_middleNameController.text.trim().isNotEmpty) _middleNameController.text.trim(),
      _lastNameController.text.trim(),
      if (_suffixController.text.trim().isNotEmpty) _suffixController.text.trim(),
    ];
    return parts.join(' ');
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final initial = _selectedDob ?? DateTime(now.year - 22, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1920, 1, 1),
      lastDate: now,
      helpText: 'Select Date of Birth',
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobController.text = _formatDate(picked);
      });
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}, ${date.year}';
  }

  Future<void> _pickCustomPhoto(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (file != null && mounted) {
        setState(() {
          _pickedPhotoPath = file.path;
        });
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to access photo on this device.')),
        );
      }
    }
  }

  void _showProfilePicturePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Profile Picture',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primarySlate,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Take or upload a real photo of your face (no illustrations or avatars).',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Photo Requirements:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primarySlate,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '• Plain white background\n'
                        '• Well-lit area, facing forward\n'
                        '• No accessories (no caps, face masks, or sunglasses)\n'
                        '• Must clearly show your real face for passenger & driver safety',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickCustomPhoto(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_rounded, size: 18),
                        label: const Text('Upload Photo'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accentEmerald,
                          side: const BorderSide(color: AppTheme.accentEmeraldDark, width: 1.5),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _pickCustomPhoto(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_rounded, size: 18),
                        label: const Text('Take Photo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentEmerald,
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onContinue() {
    if (_formKey.currentState!.validate()) {
      if (widget.role == UserRole.driver) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DriverRequirementsChecklistScreen(
              phoneNumber: widget.phoneNumber,
              fullName: _composeFullName(),
              passengerCategory: widget.passengerCategory,
              birthDate: _selectedDob,
              profilePhotoPath: _pickedPhotoPath,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => IdUploadScreen(
              phoneNumber: widget.phoneNumber,
              fullName: _composeFullName(),
              role: widget.role,
              passengerCategory: widget.passengerCategory,
              initialBirthDate: _selectedDob,
              initialProfilePhotoPath: _pickedPhotoPath,
            ),
          ),
        );
      }
    }
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14, fontWeight: FontWeight.w400),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.accentEmerald, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.cancelRed, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.cancelRed, width: 1.5),
      ),
    );
  }

  Widget _buildFieldLabel(String text, {bool isRequired = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.primarySlate,
            ),
          ),
          if (!isRequired) ...[
            const SizedBox(width: 4),
            Text(
              '(Optional)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatarPreview() {
    Widget avatarContent;
    if (_pickedPhotoPath != null && !kIsWeb) {
      avatarContent = ClipOval(
        child: Image.file(
          File(_pickedPhotoPath!),
          width: 96,
          height: 96,
          fit: BoxFit.cover,
        ),
      );
    } else {
      avatarContent = CircleAvatar(
        radius: 48,
        backgroundColor: const Color(0xFFF1F5F9),
        child: Icon(
          Icons.person_rounded,
          size: 52,
          color: Colors.grey.shade400,
        ),
      );
    }

    return Center(
      child: Semantics(
        button: true,
        label: 'Choose or upload profile picture',
        child: GestureDetector(
          onTap: _showProfilePicturePicker,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _pickedPhotoPath != null
                        ? AppTheme.accentEmerald
                        : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: avatarContent,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppTheme.accentEmerald,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Fill Personal Info',
          style: TextStyle(
            color: AppTheme.primarySlate,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.primarySlate, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      _buildAvatarPreview(),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Tap to take or upload your real photo\n(White background, no caps, masks, or sunglasses)',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Last Name
                      _buildFieldLabel('Last Name'),
                      TextFormField(
                        controller: _lastNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: _fieldDecoration(hintText: 'Last Name'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your last name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // First Name
                      _buildFieldLabel('First Name'),
                      TextFormField(
                        controller: _firstNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: _fieldDecoration(hintText: 'First Name'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your first name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Middle Name & Suffix
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Middle Name', isRequired: false),
                                TextFormField(
                                  controller: _middleNameController,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: _fieldDecoration(hintText: 'Middle Name'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Suffix', isRequired: false),
                                TextFormField(
                                  controller: _suffixController,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: _fieldDecoration(hintText: 'Jr., III'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Phone Number (Auto-filled & OTP verified)
                      _buildFieldLabel('Phone Number'),
                      TextFormField(
                        controller: _phoneController,
                        readOnly: true,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primarySlate,
                        ),
                        decoration: _fieldDecoration(
                          hintText: '+63 9XX XXX XXXX',
                          prefixIcon: const Icon(
                            Icons.phone_android_rounded,
                            color: AppTheme.primarySlate,
                            size: 20,
                          ),
                          suffixIcon: Container(
                            margin: const EdgeInsets.only(right: 10, top: 10, bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.accentEmeraldLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 13, color: AppTheme.accentEmeraldDark),
                                SizedBox(width: 4),
                                Text(
                                  'Verified',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.accentEmeraldDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Gender (All gender options)
                      _buildFieldLabel('Gender'),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedGender,
                        isExpanded: true,
                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade600),
                        decoration: _fieldDecoration(hintText: 'Gender'),
                        hint: Text(
                          'Gender',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        ),
                        items: _genderOptions
                            .map(
                              (g) => DropdownMenuItem<String>(
                                value: g,
                                child: Text(
                                  g,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    color: AppTheme.primarySlate,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => _selectedGender = value);
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select your gender';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Date of Birth
                      _buildFieldLabel('Date of Birth'),
                      TextFormField(
                        controller: _dobController,
                        readOnly: true,
                        onTap: _pickDateOfBirth,
                        decoration: _fieldDecoration(
                          hintText: 'Date of Birth',
                          suffixIcon: Icon(
                            Icons.calendar_today_rounded,
                            color: Colors.grey.shade600,
                            size: 18,
                          ),
                        ),
                        validator: (value) {
                          if (_selectedDob == null) {
                            return 'Please select your date of birth';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Continue Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentEmerald,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
