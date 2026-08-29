import 'package:flutter/material.dart';
import '../auth/models/user_model.dart';
import 'face_scan_screen.dart';

class IdUploadScreen extends StatefulWidget {
  final String phoneNumber;
  final String fullName;
  final UserRole role;

  const IdUploadScreen({
    super.key,
    required this.phoneNumber,
    required this.fullName,
    required this.role,
  });

  @override
  State<IdUploadScreen> createState() => _IdUploadScreenState();
}

class _IdUploadScreenState extends State<IdUploadScreen> {
  String _selectedIdType = "Student ID";
  bool _isIdUploaded = false;

  final List<String> _riderIdTypes = [
    "Student ID",
    "National ID (PhilID)",
    "Senior Citizen ID",
    "PWD ID",
    "Passport",
  ];

  final List<String> _driverIdTypes = [
    "Professional Driver's License",
    "MINC / LGU Franchise Permit",
    "TODA Association Membership ID",
  ];

  List<String> get _currentIdTypes =>
      widget.role == UserRole.driver ? _driverIdTypes : _riderIdTypes;

  @override
  void initState() {
    super.initState();
    _selectedIdType = _currentIdTypes.first;
  }

  void _simulatePickIdPhoto() {
    setState(() {
      _isIdUploaded = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ID Photo captured successfully!')),
    );
  }

  void _onNext() {
    if (!_isIdUploaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture or upload your ID photo first.')),
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
          idType: _selectedIdType,
          idPhotoPath: "simulated_id_path.jpg",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDriver = widget.role == UserRole.driver;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 1: Upload Government ID'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                isDriver ? 'Driver License & Permit Verification' : 'Identity Verification',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                isDriver
                    ? 'Upload a clear photo of your Driver\'s License to verify your tricycle operation permit.'
                    : 'To eliminate fake bookings, upload a valid ID to verify your PasadaNorte account.',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),

              const SizedBox(height: 28),

              DropdownButtonFormField<String>(
                value: _selectedIdType,
                decoration: const InputDecoration(
                  labelText: 'Select ID Type',
                  prefixIcon: Icon(Icons.badge),
                ),
                items: _currentIdTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type, style: const TextStyle(fontSize: 14)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedIdType = val);
                },
              ),

              const SizedBox(height: 24),

              GestureDetector(
                onTap: _simulatePickIdPhoto,
                child: Container(
                  width: double.infinity,
                  height: 220,
                  decoration: BoxDecoration(
                    color: _isIdUploaded ? Colors.green.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isIdUploaded ? Colors.green : Colors.grey.shade400,
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: _isIdUploaded
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 56),
                            const SizedBox(height: 12),
                            Text(
                              '$_selectedIdType Uploaded',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text('Tap to retake photo', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, color: Colors.blue.shade900, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'Tap to Take Photo of $_selectedIdType',
                              style: TextStyle(
                                color: Colors.blue.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Ensure ID details & photo are clearly visible',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 40),

              ElevatedButton(
                onPressed: _onNext,
                child: const Text('Next: Live Face Scan'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
