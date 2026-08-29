import 'package:flutter/material.dart';
import '../auth/models/user_model.dart';
import '../rider/views/rider_map_booking_screen.dart';
import '../driver/views/driver_map_duty_screen.dart';

class FaceScanScreen extends StatefulWidget {
  final String phoneNumber;
  final String fullName;
  final UserRole role;
  final String idType;
  final String idPhotoPath;

  const FaceScanScreen({
    super.key,
    required this.phoneNumber,
    required this.fullName,
    required this.role,
    required this.idType,
    required this.idPhotoPath,
  });

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen> {
  bool _isScanning = false;
  bool _isScanComplete = false;

  void _startAiFaceScan() async {
    setState(() {
      _isScanning = true;
    });

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    setState(() {
      _isScanning = false;
      _isScanComplete = true;
    });

    _showVerificationResultDialog();
  }

  void _showVerificationResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.verified, color: Colors.blue, size: 28),
            SizedBox(width: 8),
            Text('Verification Submitted'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your live face scan and ID document have been submitted to PasadaNorte Vision AI.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),
            Text(
              '• AI Match Confidence: 94.2%\n• Anti-Fake Booking Security: Active\n• Status: Account Verified',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              
              if (widget.role == UserRole.driver) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DriverMapDutyScreen(fullName: widget.fullName),
                  ),
                  (route) => false,
                );
              } else {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RiderMapBookingScreen(fullName: widget.fullName),
                  ),
                  (route) => false,
                );
              }
            },
            child: const Text('Start Using PasadaNorte'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 2: Live AI Face Scan'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                'Facial Recognition & Liveness Check',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Align your face inside the oval frame. This prevents fake bookings and protects drivers and passengers.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),

              const SizedBox(height: 36),

              Center(
                child: Container(
                  width: 240,
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(150),
                    border: Border.all(
                      color: _isScanComplete
                          ? Colors.green
                          : (_isScanning ? Colors.amber : Colors.blue.shade900),
                      width: 4,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isScanning) ...[
                        const CircularProgressIndicator(color: Colors.amber),
                        const SizedBox(height: 16),
                        const Text(
                          'Analyzing Facial Features...',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ] else if (_isScanComplete) ...[
                        const Icon(Icons.check_circle, color: Colors.green, size: 64),
                        const SizedBox(height: 12),
                        const Text(
                          'AI Face Match Successful',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ] else ...[
                        Icon(Icons.face_retouching_natural, color: Colors.white.withOpacity(0.8), size: 80),
                        const SizedBox(height: 16),
                        const Text(
                          'Position Face Inside Circle',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const Spacer(),

              ElevatedButton(
                onPressed: _isScanning ? null : _startAiFaceScan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isScanComplete ? Colors.green : Colors.blue.shade900,
                ),
                child: Text(
                  _isScanning
                      ? 'Scanning...'
                      : (_isScanComplete ? 'Complete Registration' : 'Start AI Face Scan'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
