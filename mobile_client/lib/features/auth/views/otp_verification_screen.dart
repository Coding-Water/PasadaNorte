import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/driver_stats_service.dart';
import '../../../core/services/session_cache_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../driver/views/driver_map_duty_screen.dart';
import '../../fare/services/fare_calculator_service.dart';
import '../../rider/views/passenger_service_hub_screen.dart';
import 'driver_application_status_screen.dart';
import 'passenger_application_status_screen.dart';
import 'role_selection_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final Map<String, dynamic>? existingUser;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    this.existingUser,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  String? _errorText;

  int _resendCountdown = 60;
  int _remainingAttempts = 10;
  bool _isLockedOut = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    for (final node in _focusNodes) {
      node.addListener(_onFocusChanged);
    }
    _startCountdownTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendOtpSms();
    });
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  void _startCountdownTimer() {
    _timer?.cancel();
    setState(() => _resendCountdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendCountdown > 1) {
        setState(() => _resendCountdown--);
      } else {
        setState(() => _resendCountdown = 0);
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.removeListener(_onFocusChanged);
      node.dispose();
    }
    super.dispose();
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  Future<void> _sendOtpSms() async {
    final client = SupabaseService.client;
    if (client == null) return;
    try {
      await client.functions.invoke(
        'send-otp-sms',
        body: {'phone_number': widget.phoneNumber},
      );
    } on FunctionException catch (e) {
      final details = e.details;
      final serverMsg = details is Map
          ? (details['error'] ?? details['message'])?.toString()
          : null;
      if (mounted) {
        setState(() {
          _errorText = e.status == 429
              ? (serverMsg ??
                  'An OTP was just sent. Please check your SMS or wait before resending.')
              : (serverMsg ?? 'Unable to send OTP SMS. Please tap Resend Code.');
        });
      }
      debugPrint('send-otp-sms failed (${e.status}): $e');
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'Unable to send OTP SMS. Please tap Resend Code.';
        });
      }
      debugPrint('send-otp-sms failed: $e');
    }
  }

  Future<void> _resendOtp() async {
    if (_resendCountdown > 0 || _isLockedOut) return;
    _startCountdownTimer();
    setState(() => _errorText = null);
    await _sendOtpSms();
  }

  Future<void> _verifyOtp() async {
    if (_isLockedOut || _otpCode.length < 6) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    bool isValid = false;
    String failureMessage = 'Invalid OTP code. Please try again.';
    final client = SupabaseService.client;

    if (client == null) {
      failureMessage =
          'OTP verification service is unavailable. Please try again.';
    } else {
      try {
        final response = await client.functions.invoke(
          'verify-otp-sms',
          body: {
            'phone_number': widget.phoneNumber,
            'code': _otpCode,
          },
        );
        final data = response.data;
        if (data is Map && data['verified'] == true) {
          isValid = true;
        } else if (data is Map && data['error'] != null) {
          failureMessage = data['error'].toString();
        }
      } on FunctionException catch (e) {
        final details = e.details;
        if (details is Map &&
            (details['error'] != null || details['message'] != null)) {
          failureMessage = (details['error'] ?? details['message']).toString();
        } else {
          failureMessage =
              'Verification failed (HTTP ${e.status}). Please try again.';
        }
      } catch (_) {
        failureMessage = 'Invalid OTP code. Please try again.';
      }
    }

    if (!mounted) return;

    if (!isValid) {
      for (final controller in _controllers) {
        controller.clear();
      }
      setState(() {
        _isLoading = false;
        _remainingAttempts--;
        if (_remainingAttempts <= 0) {
          _isLockedOut = true;
        }
        _errorText = _isLockedOut
            ? 'Maximum attempts exceeded. Verification locked.'
            : failureMessage;
      });
      if (!_isLockedOut) {
        _focusNodes.first.requestFocus();
      }
      return;
    }

    setState(() {
      _isLoading = false;
    });

    if (widget.existingUser != null) {
      await _completeExistingUserLogin(widget.existingUser!);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoleSelectionScreen(phoneNumber: widget.phoneNumber),
      ),
    );
  }

  Future<void> _completeExistingUserLogin(
      Map<String, dynamic> existingUser) async {
    final fullPhoneNumber = widget.phoneNumber;
    final fullName = (existingUser['full_name'] as String?) ?? 'Laoag User';
    final roleStr = (existingUser['role'] as String?) ?? 'rider';

    if (roleStr == 'toda_admin' || roleStr == 'minc_admin') {
      return;
    }

    if (roleStr == 'driver') {
      final appRow =
          await SupabaseService.getDriverApplicationByPhone(fullPhoneNumber);
      if (!mounted) return;
      final appStatus = (appRow?['application_status'] ?? '').toString();
      final isPendingReview = appRow != null && appStatus != 'approved';
      DriverStatsService.isFranchiseActive = !isPendingReview;
      final plate = (appRow?['plate_or_mv_file'] ?? '').toString().trim();
      final toda = (appRow?['toda_code'] ?? '').toString().trim();
      if (plate.isNotEmpty) DriverStatsService.plateNumber = plate;
      if (toda.isNotEmpty) DriverStatsService.todaAssociation = toda;

      await SessionCacheService.saveDriverSession(
        phoneNumber: fullPhoneNumber,
        fullName: fullName,
        isPendingReview: isPendingReview,
      );
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => isPendingReview
              ? DriverApplicationStatusScreen(
                  phoneNumber: fullPhoneNumber,
                  fullName: fullName,
                )
              : DriverMapDutyScreen(fullName: fullName),
        ),
        (route) => false,
      );
      return;
    }

    final idTypeStr =
        (existingUser['id_type'] as String?) ?? 'National ID (PhilID)';
    PassengerCategory lockedCat = PassengerCategory.regular;
    if (idTypeStr.toUpperCase().contains('STUDENT')) {
      lockedCat = PassengerCategory.student;
    } else if (idTypeStr.toUpperCase().contains('SENIOR') ||
        idTypeStr.toUpperCase().contains('PWD')) {
      lockedCat = PassengerCategory.senior;
    }

    final riderStatus =
        (existingUser['verification_status'] as String?) ?? 'approved';
    final isRiderPending = riderStatus != 'approved';

    await SessionCacheService.saveRiderSession(
      phoneNumber: fullPhoneNumber,
      fullName: fullName,
      idType: idTypeStr,
      isPendingReview: isRiderPending,
    );
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => isRiderPending
            ? PassengerApplicationStatusScreen(
                phoneNumber: fullPhoneNumber,
                fullName: fullName,
                passengerCategory: lockedCat,
                idType: idTypeStr,
              )
            : PassengerServiceHubScreen(
                fullName: fullName,
                lockedCategory: lockedCat,
                verifiedIdType: idTypeStr,
              ),
      ),
      (route) => false,
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
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.primarySlate),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(0, constraints.maxHeight - 24.0),
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      const Text(
                        'Enter OTP Code 🔐',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primarySlate,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Check your messages! We've sent a one-time code to ${widget.phoneNumber}. Enter the code below to verify your account and continue.",
                        style: const TextStyle(
                          fontSize: 14.5,
                          color: Color(0xFF6B7280),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 36),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          6,
                          (index) {
                            final isFocused = _focusNodes[index].hasFocus;
                            return SizedBox(
                              width: 48,
                              height: 58,
                              child: TextField(
                                controller: _controllers[index],
                                focusNode: _focusNodes[index],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primarySlate,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(1),
                                ],
                                onChanged: (value) {
                                  if (_errorText != null) {
                                    setState(() => _errorText = null);
                                  }
                                  if (value.isNotEmpty && index < 5) {
                                    _focusNodes[index + 1].requestFocus();
                                  } else if (value.isEmpty && index > 0) {
                                    _focusNodes[index - 1].requestFocus();
                                  }
                                  if (_otpCode.length == 6 && !_isLoading) {
                                    _verifyOtp();
                                  }
                                },
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: isFocused
                                      ? AppTheme.accentEmeraldLight
                                      : const Color(0xFFEAEEF3),
                                  contentPadding: EdgeInsets.zero,
                                  counterText: '',
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFCBD5E1),
                                      width: 1.2,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: AppTheme.accentEmerald,
                                      width: 1.8,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (_errorText != null) ...[
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            _errorText!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.cancelRed,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      Center(
                        child: Column(
                          children: [
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6B7280),
                                ),
                                children: [
                                  const TextSpan(text: 'You can resend the code in '),
                                  TextSpan(
                                    text: '$_resendCountdown',
                                    style: const TextStyle(
                                      color: AppTheme.accentEmerald,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const TextSpan(text: ' seconds'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: (_resendCountdown > 0 || _isLockedOut)
                                  ? null
                                  : _resendOtp,
                              child: Text(
                                'Resend code',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: (_resendCountdown > 0 || _isLockedOut)
                                      ? const Color(0xFF9CA3AF)
                                      : AppTheme.accentEmerald,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading || _isLockedOut ? null : _verifyOtp,
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
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(_isLockedOut ? 'Account Locked' : 'Verify Code'),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
