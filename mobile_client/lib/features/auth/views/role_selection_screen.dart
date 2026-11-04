import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../admin/views/web_admin_portal_screen.dart';
import '../../fare/services/fare_calculator_service.dart';
import '../models/user_model.dart';
import 'id_upload_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  final String phoneNumber;

  const RoleSelectionScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  UserRole _selectedRole = UserRole.rider;
  PassengerCategory _selectedPassengerCategory = PassengerCategory.regular;
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_formKey.currentState!.validate()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IdUploadScreen(
            phoneNumber: widget.phoneNumber,
            fullName: _nameController.text.trim(),
            role: _selectedRole,
            passengerCategory: _selectedRole == UserRole.rider
                ? _selectedPassengerCategory
                : PassengerCategory.regular,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Setup'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Are you a Passenger or a Driver?',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primarySlate,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose your account role and enter your full name as shown on your identification card.',
                  style: TextStyle(color: Colors.black54, fontSize: 13.5),
                ),

                const SizedBox(height: 22),

                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'Juan Dela Cruz',
                    prefixIcon: Icon(Icons.person_rounded),
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

                const Text(
                  '1. Select Account Role:',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primarySlate,
                  ),
                ),
                const SizedBox(height: 12),

                // Card 1: Passenger
                GestureDetector(
                  onTap: () => setState(() => _selectedRole = UserRole.rider),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _selectedRole == UserRole.rider
                          ? const Color(0xFFF0FDF4)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _selectedRole == UserRole.rider
                            ? AppTheme.accentEmerald
                            : Colors.grey.shade300,
                        width: _selectedRole == UserRole.rider ? 2.2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.accentEmerald.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.directions_walk_rounded,
                            color: AppTheme.accentEmerald,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Passenger / Commuter',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primarySlate,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Book a Ride or Pa-Deliver across Laoag City with fixed ordinance fares.',
                                style: TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          _selectedRole == UserRole.rider
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: _selectedRole == UserRole.rider
                              ? AppTheme.accentEmerald
                              : Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Card 2: Tricycle Driver
                GestureDetector(
                  onTap: () => setState(() => _selectedRole = UserRole.driver),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _selectedRole == UserRole.driver
                          ? const Color(0xFFFEF3C7)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _selectedRole == UserRole.driver
                            ? const Color(0xFFD97706)
                            : Colors.grey.shade300,
                        width: _selectedRole == UserRole.driver ? 2.2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFDE68A),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.electric_rickshaw_rounded,
                            color: Color(0xFFB45309),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tricycle Driver (TODA)',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primarySlate,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Accept rides & deliveries, view thermal demand heatmaps & Digital Pila.',
                                style: TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          _selectedRole == UserRole.driver
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: _selectedRole == UserRole.driver
                              ? const Color(0xFFD97706)
                              : Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Passenger Fare Classification Selector (Only when Passenger is selected!)
                if (_selectedRole == UserRole.rider) ...[
                  const SizedBox(height: 24),
                  const Text(
                    '2. Select Passenger Fare Classification:',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primarySlate,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Your fare rate is automatically locked to your verified account so you don\'t have to switch it on every trip.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),

                  _buildPassengerCategoryTile(
                    category: PassengerCategory.regular,
                    title: 'Regular Commuter / Tourist',
                    subtitle: 'Standard Laoag Fare: ₱20.00 first km + ₱2.00/km',
                    badge: 'Valid Government ID',
                    icon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 8),
                  _buildPassengerCategoryTile(
                    category: PassengerCategory.student,
                    title: 'Student (Discounted Fare)',
                    subtitle: 'Discounted Rate: ₱15.00 first km + 20% LTFRB discount',
                    badge: 'Requires School / Student ID Photo',
                    icon: Icons.school_rounded,
                  ),
                  const SizedBox(height: 8),
                  _buildPassengerCategoryTile(
                    category: PassengerCategory.senior,
                    title: 'Senior Citizen / PWD (Discounted Fare)',
                    subtitle: 'Discounted Rate: ₱15.00 first km + 20% statutory discount',
                    badge: 'Requires Senior Citizen / PWD ID Photo',
                    icon: Icons.elderly_rounded,
                  ),
                ],

                const SizedBox(height: 28),

                ElevatedButton(
                  onPressed: _onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentEmerald,
                  ),
                  child: const Text('Proceed to ID & Face Verification'),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WebAdminPortalScreen()),
                      );
                    },
                    icon: const Icon(Icons.admin_panel_settings, size: 18),
                    label: const Text('Open TODA / MINC Web Admin Portal'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPassengerCategoryTile({
    required PassengerCategory category,
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
  }) {
    final bool isSelected = _selectedPassengerCategory == category;
    return GestureDetector(
      onTap: () => setState(() => _selectedPassengerCategory = category),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.accentEmerald : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.accentEmerald : AppTheme.primarySlate,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: AppTheme.primarySlate,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11.5, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.accentEmerald.withOpacity(0.15)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? AppTheme.accentEmerald : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Radio<PassengerCategory>(
              value: category,
              groupValue: _selectedPassengerCategory,
              activeColor: AppTheme.accentEmerald,
              onChanged: (v) {
                if (v != null) setState(() => _selectedPassengerCategory = v);
              },
            ),
          ],
        ),
      ),
    );
  }
}
