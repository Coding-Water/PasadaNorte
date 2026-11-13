import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../../core/services/android_permissions_service.dart';
import '../../../core/services/face_verification_service.dart';
import '../../../core/services/session_cache_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../fare/services/fare_calculator_service.dart';
import '../models/user_model.dart';
import 'driver_application_status_screen.dart';
import 'passenger_application_status_screen.dart';

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
  final String? profilePhotoPath;
  final Map<String, String> vehicleDocumentationPhotos;
  final bool isResubmissionRedo;

  const FaceScanScreen({
    super.key,
    required this.phoneNumber,
    required this.fullName,
    required this.role,
    this.passengerCategory = PassengerCategory.regular,
    required this.idType,
    required this.idPhotoPath,
    this.profilePhotoPath,
    this.vehicleDocumentationPhotos = const {},
    this.isResubmissionRedo = false,
  });

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen>
    with SingleTickerProviderStateMixin {
  bool _inLivenessStage = false;
  _LivenessStep _livenessStep = _LivenessStep.tiltLeft;
  bool _isScanning = false;
  bool _simulateLowConfidence = false;
  FaceVerificationResult? _result;
  Timer? _livenessTimer;
  late final AnimationController _progressController;
  late Animation<double> _progressAnimation;

  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  bool _useLiveCamera = false;
  bool _isProcessingFrame = false;
  bool _sawEyesOpenBeforeBlink = false;
  bool _sawBlinkClosed = false;
  String _liveFeedbackHint = 'Keep your face inside the oval frame';

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 0.12).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _livenessTimer?.cancel();
    _disposeCameraResources();
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _disposeCameraResources() async {
    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } catch (_) {}
      try {
        await controller.dispose();
      } catch (_) {}
    }
    try {
      await _faceDetector?.close();
    } catch (_) {}
    _faceDetector = null;
  }

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
    final liveStarted = camAllowed ? await _tryStartLiveCamera() : false;
    if (!mounted) return;

    if (!liveStarted) {
      _startSimulatedAutomaticLiveness();
    }
  }

  Future<bool> _tryStartLiveCamera() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return false;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return false;

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return false;
      }

      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          enableTracking: true,
          performanceMode: FaceDetectorMode.accurate,
          minFaceSize: 0.25,
        ),
      );

      _cameraController = controller;
      setState(() {
        _useLiveCamera = true;
        _inLivenessStage = true;
        _livenessStep = _LivenessStep.tiltLeft;
        _isScanning = false;
        _result = null;
        _sawEyesOpenBeforeBlink = false;
        _sawBlinkClosed = false;
        _liveFeedbackHint = 'Keep your face inside the oval frame';
      });
      _animateProgressTo(0.0, 0.12);

      await controller.startImageStream(_onCameraImage);
      return true;
    } catch (_) {
      await _disposeCameraResources();
      return false;
    }
  }

  Future<void> _onCameraImage(CameraImage image) async {
    if (_isProcessingFrame ||
        _isScanning ||
        _livenessStep == _LivenessStep.completed ||
        _faceDetector == null ||
        _cameraController == null) {
      return;
    }

    _isProcessingFrame = true;
    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector!.processImage(inputImage);
      if (!mounted || _livenessStep == _LivenessStep.completed) return;

      if (faces.isEmpty) {
        setState(() => _liveFeedbackHint = 'Position your face inside the oval frame');
        return;
      }
      if (faces.length > 1) {
        setState(() => _liveFeedbackHint = 'Only one face should be in the frame');
        return;
      }

      final face = faces.first;
      final yaw = face.headEulerAngleY ?? 0.0;
      final roll = face.headEulerAngleZ ?? 0.0;
      final leftEye = face.leftEyeOpenProbability;
      final rightEye = face.rightEyeOpenProbability;

      if (_livenessStep == _LivenessStep.tiltLeft) {
        if (yaw > 14.0 || roll > 12.0) {
          setState(() {
            _livenessStep = _LivenessStep.tiltRight;
            _liveFeedbackHint = 'Great! Now tilt your head to the right';
          });
          _animateProgressTo(0.12, 0.45);
        } else {
          setState(() => _liveFeedbackHint = 'Slowly tilt your head left');
        }
        return;
      }

      if (_livenessStep == _LivenessStep.tiltRight) {
        if (yaw < -14.0 || roll < -12.0) {
          setState(() {
            _livenessStep = _LivenessStep.blinkOnce;
            _sawEyesOpenBeforeBlink = false;
            _sawBlinkClosed = false;
            _liveFeedbackHint = 'Look straight ahead and blink once';
          });
          _animateProgressTo(0.45, 0.78);
        } else {
          setState(() => _liveFeedbackHint = 'Slowly tilt your head right');
        }
        return;
      }

      if (_livenessStep == _LivenessStep.blinkOnce) {
        if (yaw.abs() > 14.0) {
          setState(() => _liveFeedbackHint = 'Face straight ahead to blink');
          return;
        }
        if (leftEye == null || rightEye == null) return;

        if (!_sawEyesOpenBeforeBlink && leftEye > 0.65 && rightEye > 0.65) {
          _sawEyesOpenBeforeBlink = true;
          setState(() => _liveFeedbackHint = 'Now blink once');
          return;
        }

        if (_sawEyesOpenBeforeBlink &&
            !_sawBlinkClosed &&
            leftEye < 0.30 &&
            rightEye < 0.30) {
          _sawBlinkClosed = true;
          return;
        }

        if (_sawBlinkClosed && leftEye > 0.60 && rightEye > 0.60) {
          setState(() {
            _livenessStep = _LivenessStep.completed;
            _liveFeedbackHint = 'Capturing selfie...';
          });
          _animateProgressTo(0.78, 1.0);
          await _captureAndVerifyLiveSelfie();
        }
      }
    } catch (_) {
    } finally {
      _isProcessingFrame = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final controller = _cameraController;
    if (controller == null) return null;

    final camera = controller.description;
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = _orientations[controller.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    if (image.planes.length == 1) {
      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    }

    if (Platform.isAndroid && image.planes.length == 3) {
      final nv21Bytes = _convertYuv420ToNv21(image);
      return InputImage.fromBytes(
        bytes: nv21Bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );
    }

    return null;
  }

  Uint8List _convertYuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final nv21 = Uint8List(width * height + (width * height ~/ 2));

    int dstIndex = 0;
    for (int row = 0; row < height; row++) {
      final rowStart = row * yPlane.bytesPerRow;
      nv21.setRange(dstIndex, dstIndex + width, yPlane.bytes, rowStart);
      dstIndex += width;
    }

    final uvHeight = height ~/ 2;
    final uvWidth = width ~/ 2;
    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;

    for (int row = 0; row < uvHeight; row++) {
      final uRowStart = row * uPlane.bytesPerRow;
      final vRowStart = row * vPlane.bytesPerRow;
      for (int col = 0; col < uvWidth; col++) {
        nv21[dstIndex++] = vPlane.bytes[vRowStart + col * vPixelStride];
        nv21[dstIndex++] = uPlane.bytes[uRowStart + col * uPixelStride];
      }
    }
    return nv21;
  }

  Future<void> _captureAndVerifyLiveSelfie() async {
    String capturePath = 'live_capture_${DateTime.now().millisecondsSinceEpoch}.jpg';
    try {
      if (_cameraController != null && _cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        final photo = await _cameraController!.takePicture();
        capturePath = photo.path;
      }
    } catch (_) {}

    await _startFaceVerification(
      skipPermissionCheck: true,
      liveFacePath: capturePath,
    );
  }

  void _startSimulatedAutomaticLiveness() {
    _livenessTimer?.cancel();
    setState(() {
      _useLiveCamera = false;
      _inLivenessStage = true;
      _livenessStep = _LivenessStep.tiltLeft;
      _isScanning = false;
      _result = null;
      _liveFeedbackHint = 'Keep your face inside the oval frame';
    });
    _animateProgressTo(0.0, 0.33);

    _livenessTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() => _livenessStep = _LivenessStep.tiltRight);
      _animateProgressTo(0.33, 0.67);

      _livenessTimer = Timer(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        setState(() => _livenessStep = _LivenessStep.blinkOnce);
        _animateProgressTo(0.67, 1.0);

        _livenessTimer = Timer(const Duration(milliseconds: 1200), () {
          if (!mounted) return;
          setState(() => _livenessStep = _LivenessStep.completed);
          _startFaceVerification(skipPermissionCheck: true);
        });
      });
    });
  }

  void _animateProgressTo(double from, double to) {
    _progressAnimation = Tween<double>(begin: from, end: to).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
    _progressController.forward(from: 0.0);
  }

  Future<void> _startFaceVerification({
    bool skipPermissionCheck = false,
    String? liveFacePath,
  }) async {
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
      liveFacePath: liveFacePath ?? 'live_capture_${DateTime.now().millisecondsSinceEpoch}.jpg',
      profilePhotoPath: widget.profilePhotoPath,
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
    _livenessTimer?.cancel();
    _disposeCameraResources();
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
      idPhotoPath: widget.idPhotoPath,
      profilePhotoPath: widget.profilePhotoPath,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Face scan skipped for emulator testing. Account created!'),
        backgroundColor: AppTheme.accentEmerald,
        duration: Duration(seconds: 2),
      ),
    );

    if (widget.role == UserRole.driver) {
      if (widget.isResubmissionRedo) {
        unawaited(
          SupabaseService.resubmitDriverFaceScan(
            phoneNumber: widget.phoneNumber,
          ),
        );
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DriverApplicationStatusScreen(
            phoneNumber: widget.phoneNumber,
            fullName: widget.fullName,
          ),
        ),
      );
    } else {
      if (widget.isResubmissionRedo) {
        unawaited(
          SupabaseService.resubmitRiderFaceScan(
            phoneNumber: widget.phoneNumber,
            result: result,
          ),
        );
      }
      unawaited(
        SessionCacheService.saveRiderSession(
          phoneNumber: widget.phoneNumber,
          fullName: widget.fullName,
          idType: widget.idType,
          isPendingReview: true,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PassengerApplicationStatusScreen(
            phoneNumber: widget.phoneNumber,
            fullName: widget.fullName,
            passengerCategory: widget.passengerCategory,
            idType: widget.idType,
            idPhotoPath: widget.idPhotoPath,
            profilePhotoPath: widget.profilePhotoPath,
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
                if (widget.isResubmissionRedo) {
                  unawaited(
                    SupabaseService.resubmitDriverFaceScan(
                      phoneNumber: widget.phoneNumber,
                    ),
                  );
                }
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DriverApplicationStatusScreen(
                      phoneNumber: widget.phoneNumber,
                      fullName: widget.fullName,
                    ),
                  ),
                );
              } else {
                if (widget.isResubmissionRedo) {
                  unawaited(
                    SupabaseService.resubmitRiderFaceScan(
                      phoneNumber: widget.phoneNumber,
                      result: result,
                    ),
                  );
                }
                unawaited(
                  SessionCacheService.saveRiderSession(
                    phoneNumber: widget.phoneNumber,
                    fullName: widget.fullName,
                    idType: widget.idType,
                    isPendingReview: true,
                  ),
                );
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PassengerApplicationStatusScreen(
                      phoneNumber: widget.phoneNumber,
                      fullName: widget.fullName,
                      passengerCategory: widget.passengerCategory,
                      idType: widget.idType,
                      idPhotoPath: widget.idPhotoPath,
                      profilePhotoPath: widget.profilePhotoPath,
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
              _livenessTimer?.cancel();
              _disposeCameraResources();
              setState(() {
                _useLiveCamera = false;
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
    final bottomPrompt = switch (_livenessStep) {
      _LivenessStep.tiltLeft => 'Tilt left',
      _LivenessStep.tiltRight => 'Now tilt right',
      _LivenessStep.blinkOnce => 'Face forward and blink',
      _LivenessStep.completed => isComplete
          ? '${_result!.similarityScorePercent.toStringAsFixed(1)}% Match'
          : 'Verifying your selfie...',
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(0, constraints.maxHeight - 32.0),
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Center(
                    child: SizedBox(
                      width: 240,
                      height: 296,
                      child: AnimatedBuilder(
                        animation: _progressController,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: _OvalProgressBorderPainter(
                              progress: _progressAnimation.value,
                              trackColor: const Color(0xFFE5E7EB),
                              progressColor: isComplete && !_result!.isApproved
                                  ? Colors.amber
                                  : AppTheme.accentEmerald,
                            ),
                            child: child,
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F8FA),
                            borderRadius: BorderRadius.circular(140),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _buildOvalCameraContent(isComplete),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(
                      color: AppTheme.accentEmeraldLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.accentEmerald.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          bottomPrompt,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.accentEmeraldDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _liveFeedbackHint,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.accentEmeraldDark.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    dense: true,
                    activeThumbColor: AppTheme.accentEmerald,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: const Text(
                      'Simulate Low-Confidence Scan (< 85% Match)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    value: _simulateLowConfidence,
                    onChanged: (val) => setState(() => _simulateLowConfidence = val),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOvalCameraContent(bool isComplete) {
    if (_isScanning) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppTheme.accentEmerald),
          SizedBox(height: 16),
          Text(
            'Checking 1:1 match...',
            style: TextStyle(
              color: AppTheme.primarySlate,
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
            ),
          ),
        ],
      );
    }

    if (isComplete) {
      return Center(
        child: Icon(
          _result!.isApproved ? Icons.check_circle_rounded : Icons.flaky_rounded,
          color: _result!.isApproved ? AppTheme.accentEmerald : Colors.amber,
          size: 64,
        ),
      );
    }

    if (_useLiveCamera &&
        _cameraController != null &&
        _cameraController!.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _cameraController!.value.previewSize?.height ?? 240,
          height: _cameraController!.value.previewSize?.width ?? 296,
          child: CameraPreview(_cameraController!),
        ),
      );
    }

    return Center(
      child: Icon(
        switch (_livenessStep) {
          _LivenessStep.tiltLeft => Icons.rotate_left_rounded,
          _LivenessStep.tiltRight => Icons.rotate_right_rounded,
          _LivenessStep.blinkOnce => Icons.remove_red_eye_outlined,
          _LivenessStep.completed => Icons.face_rounded,
        },
        color: AppTheme.accentEmerald,
        size: 72,
      ),
    );
  }
}

class _OvalProgressBorderPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  const _OvalProgressBorderPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(3, 3, size.width - 6, size.height - 6);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.width / 2));

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5;
    canvas.drawRRect(rrect, trackPaint);

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round;

    final fullPath = Path()..addRRect(rrect);
    final metrics = fullPath.computeMetrics();
    for (final metric in metrics) {
      final startOffset = metric.length * 0.75;
      final drawLength = metric.length * progress.clamp(0.0, 1.0);
      if (drawLength <= 0) continue;

      if (startOffset + drawLength <= metric.length) {
        canvas.drawPath(
          metric.extractPath(startOffset, startOffset + drawLength),
          progressPaint,
        );
      } else {
        final firstPart = metric.length - startOffset;
        final remaining = drawLength - firstPart;
        canvas.drawPath(
          metric.extractPath(startOffset, metric.length),
          progressPaint,
        );
        canvas.drawPath(
          metric.extractPath(0, remaining),
          progressPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OvalProgressBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
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
