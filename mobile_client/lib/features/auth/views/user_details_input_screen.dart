import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../fare/services/fare_calculator_service.dart';
import '../models/user_model.dart';
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
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onProceedToIdUpload() {
    if (_formKey.currentState!.validate()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IdUploadScreen(
            phoneNumber: widget.phoneNumber,
            fullName: _nameController.text.trim(),
            role: widget.role,
            passengerCategory: widget.passengerCategory,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDriver = widget.role == UserRole.driver;

    String categoryTitle = 'Regular Commuter';
    String categorySubtitle = 'Standard Laoag ordinance rate: ₱20.00 1st km + ₱2.00/km';
    IconData categoryIcon = Icons.person_rounded;
    Color categoryColor = const Color(0xFF0284C7);
    Color categoryBg = const Color(0xFFE0F2FE);

    if (isDriver) {
      categoryTitle = 'Tricycle Driver (TODA)';
      categorySubtitle = 'Laoag Paratransit Franchise • Professional Driver';
      categoryIcon = Icons.electric_rickshaw_rounded;
      categoryColor = const Color(0xFFD97706);
      categoryBg = const Color(0xFFFEF3C7);
    } else if (widget.passengerCategory == PassengerCategory.student) {
      categoryTitle = 'Student Passenger (20% Off)';
      categorySubtitle = 'Statutory discounted rate: ₱15.00 1st km (RA 11314)';
      categoryIcon = Icons.school_rounded;
      categoryColor = AppTheme.accentEmerald;
      categoryBg = const Color(0xFFDCFCE7);
    } else if (widget.passengerCategory == PassengerCategory.senior ||
        widget.passengerCategory == PassengerCategory.pwd) {
      categoryTitle = 'Senior / PWD Passenger (20% Off)';
      categorySubtitle = 'Statutory discounted rate: ₱15.00 1st km (RA 9994 / 10754)';
      categoryIcon = Icons.accessible_rounded;
      categoryColor = AppTheme.accentEmerald;
      categoryBg = const Color(0xFFDCFCE7);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(isDriver ? 'Driver Profile Details' : 'Passenger Profile Details'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Confirmed Classification Badge Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: categoryBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(categoryIcon, color: categoryColor, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              categoryTitle,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primarySlate,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              categorySubtitle,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.check_circle_rounded, color: AppTheme.accentEmerald, size: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'What is your Full Name?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primarySlate,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your official full name as printed on your identification card. This will be verified during the ID and face verification steps.',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // Pre-filled verified phone number display
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_android_rounded, size: 18, color: AppTheme.primarySlate),
                      const SizedBox(width: 10),
                      Text(
                        widget.phoneNumber,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primarySlate,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, size: 12, color: Color(0xFF15803D)),
                            SizedBox(width: 4),
                            Text(
                              'OTP Verified',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Full Name Input
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full Legal Name',
                    hintText: 'e.g. Juan Dela Cruz',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your full name';
                    }
                    if (value.trim().split(' ').length < 2) {
                      return 'Please enter your first and last name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Individual Screens Next Steps Roadmap
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Color(0xFF16A34A), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Individual Verification Steps Ahead',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isDriver
                            ? '• Screen 1: Driver Professional License, Clearances & Vehicle Specs\n• Screen 2: 1:1 Live Face Verification'
                            : '• Screen 1: Upload your ${widget.passengerCategory == PassengerCategory.student ? "Student ID" : (widget.passengerCategory == PassengerCategory.senior ? "Senior / PWD ID" : "Government ID")}\n• Screen 2: 1:1 Live Face Verification',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF166534),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Proceed Button
                ElevatedButton(
                  onPressed: _onProceedToIdUpload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentEmerald,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Proceed to ID & Face Verification',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
