import 'package:flutter/material.dart';
import '../../../core/services/android_permissions_service.dart';
import '../../../core/services/face_verification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../driver/views/driver_map_duty_screen.dart';
import '../../fare/services/fare_calculator_service.dart';
import '../../rider/views/passenger_service_hub_screen.dart';
import '../models/user_model.dart';

class FaceScanScreen extends StatefulWidget {
  final String phoneNumber;
  final String fullName;
  final UserRole role;
  final PassengerCategory passengerCategory;
  final String idType;
  final String idPhotoPath;
  final Map<String, String> vehicleDocumentationPhotos;

  const FaceScanScreen({
    super.key,
    required this.phoneNumber,
    required this.fullName,
    required this.role,
    this.passengerCategory = PassengerCategory.regular,
    required this.idType,
    required this.idPhotoPath,
    this.vehicleDocumentationPhotos = const {},
  });

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen> {
  bool _isScanning = false;
  bool _simulateLowConfidence = false;
  FaceVerificationResult? _result;

  Future<void> _startFaceVerification() async {
    final camAllowed = await AndroidPermissionsService.ensureCameraPermission(context);
    if (!camAllowed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera permission is required for 1:1 live face verification.'),
        ),
      );
      return;
    }

    setState(() {
      _isScanning = true;
    });

    final result = await FaceVerificationService.verifyOneToOne(
      fullName: widget.fullName,
      phoneNumber: widget.phoneNumber,
      role: widget.role,
      passengerCategory: widget.passengerCategory,
      idType: widget.idType,
      idPhotoPath: widget.idPhotoPath,
      liveFacePath: 'live_capture_${DateTime.now().millisecondsSinceEpoch}.jpg',
      simulateLowConfidenceCase: _simulateLowConfidence,
    );

    if (!mounted) return;
    setState(() {
      _isScanning = false;
      _result = result;
    });

    _showVerificationResultDialog(result);
  }

  void _showVerificationResultDialog(FaceVerificationResult result) {
    final bool approved = result.isApproved;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Icon(
              approved ? Icons.verified_rounded : Icons.admin_panel_settings_rounded,
              color: approved ? AppTheme.accentEmerald : Colors.amber.shade800,
              size: 28,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                approved ? '1:1 Face Match Verified' : 'Referred to Admin Review',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.decisionNote,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: approved ? const Color(0xFFF0FDF4) : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: approved ? AppTheme.accentEmerald : Colors.amber.shade400,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• 1:1 Cosine Similarity: ${result.similarityScorePercent.toStringAsFixed(1)}%',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                  Text(
                    '• Processing Latency: ${(result.processingTimeMs / 1000).toStringAsFixed(2)}s (Target < 3.0s)',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (widget.role == UserRole.rider)
                    Text(
                      '• Locked Fare Tier: ${widget.passengerCategory.name.toUpperCase()} (${widget.idType})',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  if (widget.role == UserRole.driver)
                    Text(
                      '• Vehicle Documentation: ${widget.vehicleDocumentationPhotos.length}/4 Angles Submitted (Front, Back, Left, Right)',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  Text(
                    '• Status: ${approved ? "Approved (FAR <= 1% Target)" : "Pending TODA/MINC Web Portal Review"}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: approved ? Colors.green.shade900 : Colors.amber.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (widget.role == UserRole.driver) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DriverMapDutyScreen(fullName: widget.fullName),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PassengerServiceHubScreen(
                      fullName: widget.fullName,
                      lockedCategory: widget.passengerCategory,
                      verifiedIdType: widget.idType,
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
            child: Text(approved ? 'Continue to PasadaNorte' : 'Continue (Preview Mode)'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isComplete = _result != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 2: 1:1 Face Verification'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              const SizedBox(height: 8),
              const Text(
                '1:1 Live Face vs. ID Portrait Check',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primarySlate,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Comparing your live selfie with your ${widget.idType} portrait (ISO/IEC 19795-1:2021 target: FAR <= 1%, FRR <= 10%, < 3s).',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 12.5),
              ),

              const SizedBox(height: 24),

              Center(
                child: Container(
                  width: 220,
                  height: 270,
                  decoration: BoxDecoration(
                    color: AppTheme.primarySlate,
                    borderRadius: BorderRadius.circular(140),
                    border: Border.all(
                      color: isComplete
                          ? (_result!.isApproved ? AppTheme.accentEmerald : Colors.amber)
                          : (_isScanning ? Colors.amber : AppTheme.accentEmerald),
                      width: 4,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isScanning) ...[
                        const CircularProgressIndicator(color: AppTheme.accentEmerald),
                        const SizedBox(height: 16),
                        const Text(
                          'Comparing 1:1 Face Embeddings...',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 12.5),
                        ),
                      ] else if (isComplete) ...[
                        Icon(
                          _result!.isApproved ? Icons.check_circle_rounded : Icons.flaky_rounded,
                          color: _result!.isApproved ? AppTheme.accentEmerald : Colors.amber,
                          size: 60,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${_result!.similarityScorePercent.toStringAsFixed(1)}% Match',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          '${(_result!.processingTimeMs / 1000).toStringAsFixed(2)}s latency',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ] else ...[
                        Icon(
                          Icons.face_retouching_natural_rounded,
                          color: Colors.white.withOpacity(0.85),
                          size: 76,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Align Face Inside Oval Frame',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              SwitchListTile(
                dense: true,
                activeColor: AppTheme.accentEmerald,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: const Text(
                  'Simulate Low-Confidence Scan (< 85% Match)',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Routes registration to TODA/MINC Web Portal for manual admin review',
                  style: TextStyle(fontSize: 11),
                ),
                value: _simulateLowConfidence,
                onChanged: (val) => setState(() => _simulateLowConfidence = val),
              ),

              const Spacer(),

              ElevatedButton(
                onPressed: _isScanning ? null : _startFaceVerification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentEmerald,
                ),
                child: Text(
                  _isScanning
                      ? 'Verifying 1:1 Face Match...'
                      : (isComplete ? 'Re-run 1:1 Face Verification' : 'Capture & Run 1:1 Verification'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
