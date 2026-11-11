import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../driver/views/driver_map_duty_screen.dart';
import '../../fare/services/fare_calculator_service.dart';
import '../../rider/views/passenger_service_hub_screen.dart';
import 'otp_verification_screen.dart';
import 'welcome_onboarding_screen.dart';

class PhoneInputScreen extends StatefulWidget {
  final bool initialIsRegisterMode;

  const PhoneInputScreen({
    super.key,
    this.initialIsRegisterMode = false,
  });

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  late bool _isRegisterMode;
  bool _isCheckingAccount = false;

  @override
  void initState() {
    super.initState();
    _isRegisterMode = widget.initialIsRegisterMode;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    if (!_formKey.currentState!.validate()) return;

    final fullPhoneNumber = '+63${_phoneController.text.trim()}';

    if (!_isRegisterMode) {
      setState(() => _isCheckingAccount = true);
      final existingUser = await SupabaseService.findUserByPhone(fullPhoneNumber);
      if (!mounted) return;
      setState(() => _isCheckingAccount = false);

      if (existingUser != null) {
        final fullName = (existingUser['full_name'] as String?) ?? 'Laoag User';
        final roleStr = (existingUser['role'] as String?) ?? 'rider';

        if (roleStr == 'toda_admin' || roleStr == 'minc_admin') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('TODA & MINC Admin accounts must sign in via the PasadaNorte Web Portal (browser).'),
              backgroundColor: AppTheme.primarySlate,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 4),
            ),
          );
          return;
        }

        if (roleStr == 'driver') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DriverMapDutyScreen(fullName: fullName),
            ),
          );
        } else {
          final idTypeStr = (existingUser['id_type'] as String?) ?? 'National ID (PhilID)';
          PassengerCategory lockedCat = PassengerCategory.regular;
          if (idTypeStr.toUpperCase().contains('STUDENT')) {
            lockedCat = PassengerCategory.student;
          } else if (idTypeStr.toUpperCase().contains('SENIOR') ||
              idTypeStr.toUpperCase().contains('PWD')) {
            lockedCat = PassengerCategory.senior;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PassengerServiceHubScreen(
                fullName: fullName,
                lockedCategory: lockedCat,
                verifiedIdType: idTypeStr,
              ),
            ),
          );
        }
        return;
      } else {
        final shouldRegister = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Account Not Found'),
            content: Text(
              'No PasadaNorte account was found for $fullPhoneNumber. '
              'Would you like to register as a Passenger or Driver?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentEmerald,
                  minimumSize: const Size(120, 44),
                ),
                child: const Text('Register Now'),
              ),
            ],
          ),
        );

        if (shouldRegister != true || !mounted) return;
        setState(() => _isRegisterMode = true);
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OtpVerificationScreen(phoneNumber: fullPhoneNumber),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primarySlate,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const WelcomeOnboardingScreen()),
              );
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modern Pill Toggle (Log In vs Register)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isRegisterMode = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !_isRegisterMode ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: !_isRegisterMode
                                  ? [const BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]
                                  : [],
                            ),
                            child: Center(
                              child: Text(
                                'Log In',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: !_isRegisterMode ? AppTheme.primarySlate : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isRegisterMode = true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _isRegisterMode ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _isRegisterMode
                                  ? [const BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]
                                  : [],
                            ),
                            child: Center(
                              child: Text(
                                'Create Account',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: _isRegisterMode ? AppTheme.primarySlate : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                Text(
                  _isRegisterMode ? 'Get moving with PasadaNorte' : 'Welcome back',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primarySlate,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isRegisterMode
                      ? 'Enter your mobile number. Next, you\'ll choose whether you are a Passenger or a Tricycle Driver.'
                      : 'Enter your registered Philippine mobile number to continue.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.4),
                ),

                const SizedBox(height: 24),

                // Uber / Grab Style Phone Field
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    hintText: '917 123 4567',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                    prefixIcon: Container(
                      margin: const EdgeInsets.only(left: 12, right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🇵🇭', style: TextStyle(fontSize: 18)),
                          SizedBox(width: 6),
                          Text(
                            '+63',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primarySlate,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your mobile phone number';
                    }
                    if (!value.trim().startsWith('9')) {
                      return 'Philippine mobile numbers must start with 9';
                    }
                    if (value.trim().length != 10) {
                      return 'Enter a valid 10-digit mobile number';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Primary CTA Button
                ElevatedButton(
                  onPressed: _isCheckingAccount ? null : _onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRegisterMode ? AppTheme.accentEmerald : AppTheme.primarySlate,
                  ),
                  child: _isCheckingAccount
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          _isRegisterMode ? 'Continue to Role Selection' : 'Continue',
                        ),
                ),

                if (!_isRegisterMode) ...[
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade200)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text(
                          'INSTANT TEST ACCOUNTS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade500,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade200)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _buildQuickAccountTile(
                    icon: Icons.person_pin_circle_rounded,
                    iconBg: const Color(0xFFDCFCE7),
                    iconColor: AppTheme.accentEmerald,
                    title: 'Passenger Mode',
                    subtitle: '+63 999 000 0001 • Book Rides & Approved Fares',
                    phoneDigits: '9990000001',
                  ),
                  const SizedBox(height: 10),
                  _buildQuickAccountTile(
                    icon: Icons.electric_rickshaw_rounded,
                    iconBg: const Color(0xFFFEF3C7),
                    iconColor: const Color(0xFFD97706),
                    title: 'Tricycle Driver Mode',
                    subtitle: '+63 999 000 0002 • Thermal Radar & Digital Pila',
                    phoneDigits: '9990000002',
                  ),
                  const SizedBox(height: 10),
                  _buildQuickAccountTile(
                    icon: Icons.admin_panel_settings_rounded,
                    iconBg: const Color(0xFFE0E7FF),
                    iconColor: const Color(0xFF1D4ED8),
                    title: 'TODA / MINC Admin Portal',
                    subtitle: '+63 999 000 0003 • 1:1 Reviews, Geofences & Fares',
                    phoneDigits: '9990000003',
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAccountTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String phoneDigits,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        _phoneController.text = phoneDigits;
        _onContinue();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
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
                      fontSize: 14,
                      color: AppTheme.primarySlate,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 15, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
