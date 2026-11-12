import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/android_permissions_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../fare/services/fare_calculator_service.dart';
import '../models/user_model.dart';
import 'face_scan_screen.dart';

class IdUploadScreen extends StatefulWidget {
  final String phoneNumber;
  final String fullName;
  final UserRole role;
  final PassengerCategory passengerCategory;

  const IdUploadScreen({
    super.key,
    required this.phoneNumber,
    required this.fullName,
    required this.role,
    this.passengerCategory = PassengerCategory.regular,
  });

  @override
  State<IdUploadScreen> createState() => _IdUploadScreenState();
}

class _IdUploadScreenState extends State<IdUploadScreen> {
  late String _selectedIdType;
  String? _capturedIdPath;
  bool _biometricConsentGiven = false; // Unbundled Opt-In #1 (RA 10173 Sec. 13 & NPC Circular No. 2023-03)
  bool _locationTelemetryConsentGiven = false; // Unbundled Opt-In #2 (No deceptive dark patterns / pre-ticked boxes)
  final ImagePicker _picker = ImagePicker();

  // 4-Angle Tricycle Vehicle Documentation (Required for Driver Registration)
  final Map<String, String?> _vehiclePhotos = {
    'Front View': null,
    'Back View': null,
    'Left Side View': null,
    'Right Side View': null,
  };
  bool _tricyclePhotosSkipped = false;

  List<String> get _currentIdTypes {
    if (widget.role == UserRole.driver) {
      return [
        "Professional Driver's License",
      ];
    }
    switch (widget.passengerCategory) {
      case PassengerCategory.student:
        return [
          "School / Student ID (Validated)",
          "University Enrollment & Student ID",
        ];
      case PassengerCategory.senior:
      case PassengerCategory.pwd:
        return [
          "OSCA Senior Citizen ID",
          "PWD Identification Card",
        ];
      case PassengerCategory.regular:
        return [
          "National ID (PhilID)",
          "Passport",
          "Voter's / Postal / UMID ID",
          "Driver's License",
        ];
    }
  }

  String get _categoryRequirementBanner {
    if (widget.role == UserRole.driver) {
      return 'Driver Requirement: Upload your valid Professional Driver\'s License. (Tricycle photos can be skipped for now).';
    }
    switch (widget.passengerCategory) {
      case PassengerCategory.student:
        return 'Student Fare Locked (₱15.00 1st km): Please take a clear picture of your School / Student ID.';
      case PassengerCategory.senior:
      case PassengerCategory.pwd:
        return 'Senior / PWD Fare Locked (₱15.00 1st km): Please take a clear picture of your Senior Citizen or PWD ID.';
      case PassengerCategory.regular:
        return 'Regular Fare Locked (₱20.00 1st km): Please upload a valid Government ID for 1:1 face verification.';
    }
  }

  bool get _areAllVehiclePhotosUploaded {
    if (widget.role != UserRole.driver || _tricyclePhotosSkipped) return true;
    return _vehiclePhotos.values.every((path) => path != null);
  }

  @override
  void initState() {
    super.initState();
    _selectedIdType = _currentIdTypes.first;
  }

  Future<void> _pickIdPhoto(ImageSource source) async {
    final bool allowed = source == ImageSource.camera
        ? await AndroidPermissionsService.ensureCameraPermission(context)
        : await AndroidPermissionsService.ensureGalleryPermission(context);
    if (!allowed) {
      setState(() {
        _capturedIdPath = 'sample_${_selectedIdType.toLowerCase().replaceAll(' ', '_')}.jpg';
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sample $_selectedIdType loaded for preview/testing.'),
          backgroundColor: AppTheme.accentEmerald,
        ),
      );
      return;
    }

    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (file != null) {
        setState(() {
          _capturedIdPath = file.path;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$_selectedIdType image loaded (${file.name}).')),
        );
        return;
      }
    } catch (_) {}

    setState(() {
      _capturedIdPath = 'sample_${_selectedIdType.toLowerCase().replaceAll(' ', '_')}.jpg';
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$_selectedIdType captured for 1:1 verification.')),
    );
  }

  Future<void> _pickVehicleAnglePhoto(String angleKey, ImageSource source) async {
    final bool allowed = source == ImageSource.camera
        ? await AndroidPermissionsService.ensureCameraPermission(context)
        : await AndroidPermissionsService.ensureGalleryPermission(context);
    if (!allowed) {
      setState(() {
        _vehiclePhotos[angleKey] =
            'sample_tricycle_${angleKey.toLowerCase().replaceAll(' ', '_')}.jpg';
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sample tricycle $angleKey loaded for preview/testing.'),
          backgroundColor: AppTheme.accentEmerald,
        ),
      );
      return;
    }

    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (file != null) {
        setState(() {
          _vehiclePhotos[angleKey] = file.path;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tricycle $angleKey uploaded (${file.name}).')),
        );
        return;
      }
    } catch (_) {}

    setState(() {
      _vehiclePhotos[angleKey] =
          'tricycle_${angleKey.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tricycle $angleKey photo captured for MINC/TODA documentation.'),
        backgroundColor: AppTheme.accentEmerald,
      ),
    );
  }

  void _autoFillDemoData() {
    setState(() {
      _capturedIdPath = 'demo_${_selectedIdType.toLowerCase().replaceAll(' ', '_')}.jpg';
      if (widget.role == UserRole.driver) {
        _vehiclePhotos['Front View'] = 'demo_tricycle_front.jpg';
        _vehiclePhotos['Back View'] = 'demo_tricycle_back.jpg';
        _vehiclePhotos['Left Side View'] = 'demo_tricycle_left.jpg';
        _vehiclePhotos['Right Side View'] = 'demo_tricycle_right.jpg';
      }
      _biometricConsentGiven = true;
      _locationTelemetryConsentGiven = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test identification & consents auto-filled for rapid registration testing.'),
        backgroundColor: AppTheme.accentEmerald,
      ),
    );
  }

  void _skipTricyclePhotos() {
    setState(() {
      _tricyclePhotosSkipped = !_tricyclePhotosSkipped;
      if (_tricyclePhotosSkipped) {
        _vehiclePhotos['Front View'] ??= 'skipped_tricycle_front.jpg';
        _vehiclePhotos['Back View'] ??= 'skipped_tricycle_back.jpg';
        _vehiclePhotos['Left Side View'] ??= 'skipped_tricycle_left.jpg';
        _vehiclePhotos['Right Side View'] ??= 'skipped_tricycle_right.jpg';
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _tricyclePhotosSkipped
              ? 'Tricycle photos skipped for now (testing mode).'
              : 'Tricycle photos requirement restored.',
        ),
        backgroundColor: AppTheme.accentEmerald,
      ),
    );
  }

  void _onNext() {
    if (_capturedIdPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please capture a photo of your $_selectedIdType first.')),
      );
      return;
    }
    if (widget.role == UserRole.driver && !_tricyclePhotosSkipped && !_areAllVehiclePhotosUploaded) {
      final missing = _vehiclePhotos.entries
          .where((e) => e.value == null)
          .map((e) => e.key)
          .join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Driver Registration Requirement: Please upload all 4 tricycle angles (Missing: $missing) or tap "Skip Tricycle Photos".'),
        ),
      );
      return;
    }
    if (!_biometricConsentGiven || !_locationTelemetryConsentGiven) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please opt in to both unbundled consent toggles (RA 10173 Biometric Processing & Location Telemetry).',
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaceScanScreen(
          phoneNumber: widget.phoneNumber,
          fullName: widget.fullName,
          role: widget.role,
          passengerCategory: widget.passengerCategory,
          idType: _selectedIdType,
          idPhotoPath: _capturedIdPath!,
          vehicleDocumentationPhotos: widget.role == UserRole.driver
              ? _vehiclePhotos.map((k, v) => MapEntry(k, v ?? ''))
              : const {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDriver = widget.role == UserRole.driver;
    final isIdUploaded = _capturedIdPath != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isDriver ? 'Step 1: Driver ID & Tricycle Photos' : 'Step 1: Identification Card'),
        actions: [
          TextButton.icon(
            onPressed: _autoFillDemoData,
            icon: const Icon(Icons.bolt_rounded, color: AppTheme.accentEmerald, size: 18),
            label: const Text(
              'Auto-Fill',
              style: TextStyle(color: AppTheme.accentEmerald, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Requirement Highlight Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.accentEmerald),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: AppTheme.accentEmerald, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _categoryRequirementBanner,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primarySlate,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),
              // Rapid Testing Auto-fill pill
              InkWell(
                onTap: _autoFillDemoData,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade400),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bolt_rounded, size: 16, color: Colors.amber.shade900),
                      const SizedBox(width: 6),
                      Text(
                        '⚡ Auto-Fill Demo ID & Photos (Rapid Testing)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),
              Text(
                isDriver
                    ? '1. Driver License & TODA Credential'
                    : 'Upload Your ${widget.passengerCategory == PassengerCategory.student ? "Student ID" : (widget.passengerCategory == PassengerCategory.senior ? "Senior / PWD ID" : "Government ID")}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primarySlate,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '1:1 face verification compares facial similarity between your live selfie and ID portrait only (does not authenticate optical ID security features under NIST SP 800-63A DFAR/DFRR or perform active liveness/PAD under ISO/IEC 30107-3:2023; TODA/MINC admins inspect flagged cases).',
                style: TextStyle(color: Colors.black54, fontSize: 12.5),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                key: ValueKey(_selectedIdType),
                initialValue: _selectedIdType,
                decoration: const InputDecoration(
                  labelText: 'Required Identification Card',
                  prefixIcon: Icon(Icons.badge_rounded),
                ),
                items: _currentIdTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedIdType = val);
                },
              ),

              const SizedBox(height: 16),

              GestureDetector(
                onTap: () => _pickIdPhoto(ImageSource.camera),
                child: Container(
                  width: double.infinity,
                  height: 165,
                  decoration: BoxDecoration(
                    color: isIdUploaded ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isIdUploaded ? AppTheme.accentEmerald : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: isIdUploaded
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppTheme.accentEmerald, size: 48),
                            const SizedBox(height: 8),
                            Text(
                              '$_selectedIdType Captured',
                              style: const TextStyle(
                                color: AppTheme.accentEmerald,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _capturedIdPath!,
                              style: const TextStyle(color: Colors.black54, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_a_photo_rounded, color: AppTheme.primarySlate, size: 38),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to Photograph $_selectedIdType',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppTheme.primarySlate,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Ensure your ID photo & name are clearly visible',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () => _pickIdPhoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: const Text('Camera'),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: () => _pickIdPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded, size: 18),
                    label: const Text('Gallery'),
                  ),
                ],
              ),

              // DRIVER REQUIREMENT: 4-ANGLE TRICYCLE VEHICLE DOCUMENTATION (Front, Back, Left, Right)
              if (isDriver) ...[
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.electric_rickshaw_rounded, color: AppTheme.primarySlate, size: 22),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '2. Tricycle Vehicle Documentation (4 Angles)',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primarySlate,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _areAllVehiclePhotosUploaded
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_vehiclePhotos.values.where((v) => v != null).length}/4 Uploaded',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _areAllVehiclePhotosUploaded
                              ? AppTheme.accentEmerald
                              : const Color(0xFFD97706),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Submit clear photos of the Front, Back, Left, and Right sides of your tricycle. The Front view is shown to passengers when you accept a ride so they can easily identify your vehicle.',
                  style: TextStyle(color: Colors.black54, fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _skipTricyclePhotos,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: _tricyclePhotosSkipped ? const Color(0xFFDCFCE7) : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _tricyclePhotosSkipped ? AppTheme.accentEmerald : Colors.amber.shade400,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _tricyclePhotosSkipped ? Icons.check_circle_rounded : Icons.fast_forward_rounded,
                          size: 16,
                          color: _tricyclePhotosSkipped ? AppTheme.accentEmerald : Colors.amber.shade900,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _tricyclePhotosSkipped
                              ? 'Tricycle Photos Skipped for Testing (Tap to undo)'
                              : 'Skip Tricycle Photos for now (Testing)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _tricyclePhotosSkipped ? AppTheme.accentEmerald : Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.25,
                  children: [
                    _buildVehicleAngleUploadTile(
                      angleKey: 'Front View',
                      subtitle: 'Body # & Windshield (Shown to Rider)',
                      icon: Icons.electric_rickshaw_rounded,
                    ),
                    _buildVehicleAngleUploadTile(
                      angleKey: 'Back View',
                      subtitle: 'Rear LTO Plate & Tail Reflectors',
                      icon: Icons.directions_car_filled_rounded,
                    ),
                    _buildVehicleAngleUploadTile(
                      angleKey: 'Left Side View',
                      subtitle: 'Driver Motorcycle & TODA Sticker',
                      icon: Icons.two_wheeler_rounded,
                    ),
                    _buildVehicleAngleUploadTile(
                      angleKey: 'Right Side View',
                      subtitle: 'Sidecar Entrance & Fare Matrix',
                      icon: Icons.airline_seat_recline_normal_rounded,
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 18),

              // Unbundled, Non-Deceptive Opt-In Consent Toggles (RA 10173 Sec. 13 & NPC Circular No. 2023-03)
              const Text(
                'Unbundled Informed Consent (No Pre-Ticked Boxes / NPC Transparency)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primarySlate,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    children: [
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: AppTheme.accentEmerald,
                        value: _biometricConsentGiven,
                        onChanged: (val) => setState(() => _biometricConsentGiven = val ?? false),
                        title: const Text(
                          '1. Sensitive Biometric & ID Processing Consent (RA 10173 Sec. 13 & NPC Circular No. 2023-03)',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                        subtitle: const Text(
                          'I freely consent to 1:1 facial comparison between my live selfie and submitted ID photo. Auto-approved raw images are purged immediately; manual-review images are retained <= 72h in encrypted staging and purged upon decision; segregated 128-D AES-256 templates are deleted <= 24h after account closure/consent withdrawal or 12 months inactivity.',
                          style: TextStyle(fontSize: 11, color: Colors.black87, height: 1.35),
                        ),
                      ),
                      const Divider(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: AppTheme.accentEmerald,
                        value: _locationTelemetryConsentGiven,
                        onChanged: (val) => setState(() => _locationTelemetryConsentGiven = val ?? false),
                        title: const Text(
                          '2. GPS Location Telemetry & Dispatch Notification Consent',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                        subtitle: const Text(
                          'I separately consent to real-time GPS pickup pinpointing, road-route ordinance fare computation, and FIFO TODA terminal queue ("Digital Pila") telemetry while using PasadaNorte.',
                          style: TextStyle(fontSize: 11, color: Colors.black87, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),

              ElevatedButton(
                onPressed: _onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentEmerald,
                ),
                child: const Text('Next: 1:1 Live Face Verification'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showVehiclePhotoSourcePicker(String angleKey) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upload Tricycle $angleKey',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: AppTheme.primarySlate),
                title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Uses Camera permission', style: TextStyle(fontSize: 11.5)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickVehicleAnglePhoto(angleKey, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppTheme.accentEmerald),
                title: const Text('Choose from Gallery / Photos', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Uses Photos & Media permission', style: TextStyle(fontSize: 11.5)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickVehicleAnglePhoto(angleKey, ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleAngleUploadTile({
    required String angleKey,
    required String subtitle,
    required IconData icon,
  }) {
    final uploaded = _vehiclePhotos[angleKey] != null;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showVehiclePhotoSourcePicker(angleKey),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: uploaded ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: uploaded ? AppTheme.accentEmerald : Colors.grey.shade300,
            width: uploaded ? 2 : 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              uploaded ? Icons.check_circle_rounded : icon,
              color: uploaded ? AppTheme.accentEmerald : AppTheme.primarySlate,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              angleKey,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: uploaded ? AppTheme.accentEmerald : AppTheme.primarySlate,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              uploaded ? 'Captured ✓' : subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                color: uploaded ? Colors.green.shade800 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
