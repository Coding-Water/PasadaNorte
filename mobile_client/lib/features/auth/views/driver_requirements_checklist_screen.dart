import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../fare/services/fare_calculator_service.dart';
import '../models/user_model.dart';
import 'id_upload_screen.dart';

class DriverRequirementsChecklistScreen extends StatelessWidget {
  final String phoneNumber;
  final String fullName;
  final PassengerCategory passengerCategory;
  final DateTime? birthDate;
  final String? profilePhotoPath;

  const DriverRequirementsChecklistScreen({
    super.key,
    required this.phoneNumber,
    required this.fullName,
    this.passengerCategory = PassengerCategory.regular,
    this.birthDate,
    this.profilePhotoPath,
  });

  Widget _buildRequirementItem(String title, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(Icons.circle, size: 6, color: Colors.black87),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: Colors.black87,
                ),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: detail),
                ],
              ),
            ),
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
        title: const Text(
          'Driver Requirements',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Please read carefully before proceeding',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'To register as a PasadaNorte driver in Laoag City, make sure you have all the following original documents and vehicle photos ready to upload.',
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFFE5E7EB)),
                    const SizedBox(height: 16),
                    const Text(
                      '1. Personal & Government Documents',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildRequirementItem(
                      'Age Eligibility',
                      'Must be 20 to 55 years old.',
                    ),
                    _buildRequirementItem(
                      'Real Selfie / Profile Photo',
                      'Plain white background, well-lit area, no caps, masks, or sunglasses.',
                    ),
                    _buildRequirementItem(
                      "Professional Driver's License",
                      'Valid and clearly readable.',
                    ),
                    _buildRequirementItem(
                      'NBI Clearance',
                      'Original copy or valid renewal receipt.',
                    ),
                    _buildRequirementItem(
                      'Barangay or Police Clearance',
                      'Valid local clearance from Laoag City.',
                    ),
                    _buildRequirementItem(
                      'Fit-to-Work Medical Certificate',
                      'Required only if you are 50 to 55 years old.',
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: Color(0xFFE5E7EB)),
                    const SizedBox(height: 16),
                    const Text(
                      '2. Motorcycle & Tricycle Documents',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildRequirementItem(
                      'Vehicle Eligibility',
                      '110cc to 200cc engine displacement, model year 2016 or newer.',
                    ),
                    _buildRequirementItem(
                      'LTO OR & CR',
                      'Official Receipt (OR) and Certificate of Registration (CR).',
                    ),
                    _buildRequirementItem(
                      'If Not Registered Under Your Name',
                      'Signed Owner Authorization Letter and Valid ID of the registered owner.',
                    ),
                    _buildRequirementItem(
                      '4-Angle Tricycle Photos',
                      'Clear photos of Front View, Back View, Left Side View, and Right Side View.',
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.4),
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Back',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => IdUploadScreen(
                              phoneNumber: phoneNumber,
                              fullName: fullName,
                              role: UserRole.driver,
                              passengerCategory: passengerCategory,
                              initialBirthDate: birthDate,
                              initialProfilePhotoPath: profilePhotoPath,
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.accentEmeraldDark,
                        side: const BorderSide(
                          color: AppTheme.accentEmeraldDark,
                          width: 1.8,
                        ),
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'I Have Complete Requirements',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accentEmeraldDark,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
