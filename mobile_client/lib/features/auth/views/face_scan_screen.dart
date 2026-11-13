import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/services/android_permissions_service.dart';
import '../../../core/services/face_verification_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../driver/views/driver_map_duty_screen.dart';
import '../../fare/services/fare_calculator_service.dart';
import '../../rider/views/passenger_service_hub_screen.dart';
import '../models/user_model.dart';

enum _LivenessStep {
  tiltLeft,
  tiltRight,
  blinkOnce,
  completed,
}

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
  bool _inLivenessStage = false;
  _LivenessStep _livenessStep = _LivenessStep.tiltLeft;
  bool _isScanning = false;
  bool _simulateLowConfidence = false;
  FaceVerificationResult? _result;

  Future<void> _enterLivenessStage() async {
    final camAllowed = await AndroidPermissionsService.ensureCameraPermission(context);
    if (!camAllowed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera unavailable: Proceeding with guided 1:1 face verification.'),
          backgroundColor: AppTheme.accentEmerald,
          duration: Duration(seconds: 2),
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _inLivenessStage = true;
      _livenessStep = _LivenessStep.tiltLeft;
      _result = null;
    });
  }

  Future<void> _advanceLivenessStep() async {
    if (_isScanning) return;

    if (_livenessStep == _LivenessStep.tiltLeft) {
      setState(() => _livenessStep = _LivenessStep.tiltRight);
      return;
    }

    if (_livenessStep == _LivenessStep.tiltRight) {
      setState(() => _livenessStep = _LivenessStep.blinkOnce);
      return;
    }

    if (_livenessStep == _LivenessStep.blinkOnce) {
      setState(() => _livenessStep = _LivenessStep.completed);
      await _startFaceVerification(skipPermissionCheck: true);
    }
  }

  Future<void> _startFaceVerification({bool skipPermissionCheck = false}) async {
    if (!skipPermissionCheck) {
      final camAllowed = await AndroidPermissionsService.ensureCameraPermission(context);
      if (!camAllowed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera unavailable: Proceeding with simulated 1:1 face verification.'),
            backgroundColor: AppTheme.accentEmerald,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }

    if (!mounted) return;
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

  void _skipFaceScan() {
    const result = FaceVerificationResult(
      similarityScorePercent: 95.0,
      processingTimeMs: 120,
      status: VerificationStatus.approved,
      decisionNote: '1:1 face match skipped for virtual Android / computer testing. Restore camera verification before physical device production release.',
      verificationImagesDeleted: true,
    );

    SupabaseService.recordFaceVerification(
      fullName: widget.fullName,
      phoneNumber: widget.phoneNumber,
      role: widget.role,
      passengerCategory: widget.passengerCategory,
      idType: widget.idType,
      result: result,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Face scan skipped for emulator testing. Account created!'),
        backgroundColor: AppTheme.accentEmerald,
        duration: Duration(seconds: 2),
      ),
    );

    if (widget.role == UserRole.driver) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DriverMapDutyScreen(fullName: widget.fullName),
        ),
      );
    } else {
      Navigator.pushReplacement(
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentEmerald,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            child: Text(approved ? 'Continue to PasadaNorte' : 'Continue (Preview Mode)'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.primarySlate, size: 20),
          onPressed: () {
            if (_inLivenessStage && !_isScanning) {
              setState(() {
                _inLivenessStage = false;
                _livenessStep = _LivenessStep.tiltLeft;
                _result = null;
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton.icon(
            onPressed: _skipFaceScan,
            icon: const Icon(Icons.fast_forward_rounded, color: AppTheme.accentEmerald, size: 18),
            label: const Text(
              'Skip (Testing)',
              style: TextStyle(
                color: AppTheme.accentEmerald,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _inLivenessStage ? _buildLivenessStage() : _buildIntroStage(),
      ),
    );
  }

  Widget _buildIntroStage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(0, constraints.maxHeight - 32.0),
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  const Text(
                    'Take a selfie to verify your identity',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primarySlate,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: 196,
                    height: 196,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: AppTheme.accentEmerald,
                        width: 4,
                      ),
                    ),
                    child: ClipOval(
                      child: CustomPaint(
                        size: const Size(196, 196),
                        painter: _PasadaNorteFaceVectorPainter(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Your selfie will be compared with your uploaded ID to verify your account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4B5563),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Make sure your selfie is within the frame and you're in a well-lit area.\nRemove anything on your face like a face mask or sunglasses.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4B5563),
                      height: 1.5,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _enterLivenessStage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentEmerald,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('Next'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLivenessStage() {
    final isComplete = _result != null;
    final stepTitle = switch (_livenessStep) {
      _LivenessStep.tiltLeft => 'Tilt your head left',
      _LivenessStep.tiltRight => 'Tilt your head right',
      _LivenessStep.blinkOnce => 'Blink once',
      _LivenessStep.completed => isComplete ? 'Verification Complete' : 'Capturing Selfie...',
    };
    final stepSubtitle = switch (_livenessStep) {
      _LivenessStep.tiltLeft => 'Slowly tilt your head slightly to the left inside the frame.',
      _LivenessStep.tiltRight => 'Now tilt your head slightly to the right inside the frame.',
      _LivenessStep.blinkOnce => 'Look straight into the camera and blink once.',
      _LivenessStep.completed => 'Comparing your live selfie with your ${widget.idType} portrait.',
    };
    final actionLabel = switch (_livenessStep) {
      _LivenessStep.tiltLeft => 'Confirm Head Tilt Left',
      _LivenessStep.tiltRight => 'Confirm Head Tilt Right',
      _LivenessStep.blinkOnce => 'Confirm Blink & Verify',
      _LivenessStep.completed => _isScanning ? 'Verifying...' : 'Re-run Face Verification',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        children: [
          Row(
            children: [
              _buildStepChip('1. Tilt Left', _livenessStep.index > 0, _livenessStep == _LivenessStep.tiltLeft),
              const SizedBox(width: 8),
              _buildStepChip('2. Tilt Right', _livenessStep.index > 1, _livenessStep == _LivenessStep.tiltRight),
              const SizedBox(width: 8),
              _buildStepChip('3. Blink Once', _livenessStep.index > 2, _livenessStep == _LivenessStep.blinkOnce),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            stepTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.primarySlate,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stepSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF4B5563),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Container(
              width: 220,
              height: 268,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(134),
                border: Border.all(
                  color: isComplete
                      ? (_result!.isApproved ? AppTheme.accentEmerald : Colors.amber)
                      : AppTheme.accentEmerald,
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
                      'Verifying 1:1 Face Match...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.primarySlate,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ] else if (isComplete) ...[
                    Icon(
                      _result!.isApproved ? Icons.check_circle_rounded : Icons.flaky_rounded,
                      color: _result!.isApproved ? AppTheme.accentEmerald : Colors.amber,
                      size: 62,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${_result!.similarityScorePercent.toStringAsFixed(1)}% Match',
                      style: const TextStyle(
                        color: AppTheme.primarySlate,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ] else ...[
                    Icon(
                      switch (_livenessStep) {
                        _LivenessStep.tiltLeft => Icons.rotate_left_rounded,
                        _LivenessStep.tiltRight => Icons.rotate_right_rounded,
                        _LivenessStep.blinkOnce => Icons.remove_red_eye_outlined,
                        _LivenessStep.completed => Icons.face_rounded,
                      },
                      color: AppTheme.accentEmerald,
                      size: 68,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      stepTitle,
                      style: const TextStyle(
                        color: AppTheme.primarySlate,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            dense: true,
            activeThumbColor: AppTheme.accentEmerald,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
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
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isScanning
                  ? null
                  : (_livenessStep == _LivenessStep.completed
                      ? () => _startFaceVerification(skipPermissionCheck: true)
                      : _advanceLivenessStep),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentEmerald,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(actionLabel),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildStepChip(String label, bool done, bool active) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: done || active ? AppTheme.accentEmeraldLight : const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: done || active ? AppTheme.accentEmerald : const Color(0xFFE5E7EB),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (done) ...[
              const Icon(Icons.check_circle_rounded, color: AppTheme.accentEmerald, size: 14),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: done || active ? AppTheme.accentEmeraldDark : const Color(0xFF6B7280),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasadaNorteFaceVectorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final bgPaint = Paint()..color = const Color(0xFFF0FDF4);
    canvas.drawCircle(Offset(cx, cy), size.width * 0.44, bgPaint);

    final scanDotPaint = Paint()..color = AppTheme.accentEmerald.withValues(alpha: 0.35);
    for (int row = -3; row <= 3; row++) {
      for (int col = -2; col <= 0; col++) {
        final dx = cx - 22 + col * 14.0;
        final dy = cy + row * 14.0;
        if (math.sqrt(math.pow(dx - cx, 2) + math.pow(dy - cy, 2)) < size.width * 0.38) {
          canvas.drawCircle(Offset(dx, dy), 2.3, scanDotPaint);
        }
      }
    }

    final strokePaint = Paint()
      ..color = AppTheme.primarySlate
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillWhite = Paint()..color = Colors.white;

    final shoulderPath = Path()
      ..moveTo(cx - 42, cy + 72)
      ..quadraticBezierTo(cx - 38, cy + 44, cx - 14, cy + 40)
      ..lineTo(cx - 12, cy + 28)
      ..lineTo(cx + 12, cy + 28)
      ..lineTo(cx + 14, cy + 40)
      ..quadraticBezierTo(cx + 38, cy + 44, cx + 42, cy + 72);
    canvas.drawPath(shoulderPath, fillWhite);
    canvas.drawPath(shoulderPath, strokePaint);

    final collarPath = Path()
      ..moveTo(cx - 14, cy + 40)
      ..lineTo(cx, cy + 52)
      ..lineTo(cx + 14, cy + 40);
    canvas.drawPath(collarPath, strokePaint);

    final headRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy - 8), width: 62, height: 76),
      const Radius.circular(31),
    );
    canvas.drawRRect(headRect, fillWhite);
    canvas.drawRRect(headRect, strokePaint);

    final leftEar = Rect.fromCenter(center: Offset(cx - 33, cy - 6), width: 10, height: 18);
    final rightEar = Rect.fromCenter(center: Offset(cx + 33, cy - 6), width: 10, height: 18);
    canvas.drawOval(leftEar, fillWhite);
    canvas.drawOval(rightEar, fillWhite);
    canvas.drawArc(leftEar, math.pi * 0.5, math.pi, false, strokePaint);
    canvas.drawArc(rightEar, -math.pi * 0.5, math.pi, false, strokePaint);

    final hairFill = Paint()..color = AppTheme.accentEmerald;
    final hairPath = Path()
      ..moveTo(cx - 31, cy - 16)
      ..quadraticBezierTo(cx - 32, cy - 50, cx, cy - 50)
      ..quadraticBezierTo(cx + 34, cy - 50, cx + 31, cy - 16)
      ..quadraticBezierTo(cx + 22, cy - 30, cx + 4, cy - 28)
      ..quadraticBezierTo(cx - 18, cy - 26, cx - 31, cy - 16)
      ..close();
    canvas.drawPath(hairPath, hairFill);
    canvas.drawPath(hairPath, strokePaint);

    final featurePaint = Paint()
      ..color = AppTheme.primarySlate
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - 12, cy - 10), 2.5, featurePaint);
    canvas.drawCircle(Offset(cx + 12, cy - 10), 2.5, featurePaint);

    final nosePath = Path()
      ..moveTo(cx, cy - 12)
      ..lineTo(cx - 2, cy - 2)
      ..lineTo(cx + 2, cy - 1);
    canvas.drawPath(nosePath, strokePaint..strokeWidth = 2.0);

    final smilePath = Path()
      ..moveTo(cx - 9, cy + 8)
      ..quadraticBezierTo(cx, cy + 16, cx + 9, cy + 8);
    canvas.drawPath(smilePath, strokePaint..strokeWidth = 2.4);

    final frameCornerPaint = Paint()
      ..color = AppTheme.accentEmerald
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy), width: size.width * 0.72, height: size.height * 0.72),
      -math.pi * 0.78,
      math.pi * 0.25,
      false,
      frameCornerPaint,
    );
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy), width: size.width * 0.72, height: size.height * 0.72),
      math.pi * 0.22,
      math.pi * 0.25,
      false,
      frameCornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
