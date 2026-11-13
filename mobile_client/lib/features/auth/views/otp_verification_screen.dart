import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import 'role_selection_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const String staticOtp = '123456';
  static const String legacyStaticOtp = '202601';

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

  void _resendOtp() {
    if (_resendCountdown > 0 || _isLockedOut) return;
    _startCountdownTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Static OTP for testing: $staticOtp (resent to ${widget.phoneNumber}).',
        ),
        backgroundColor: AppTheme.accentEmerald,
      ),
    );
  }

  void _verifyOtp() async {
    if (_isLockedOut) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account locked: maximum attempts exceeded.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_otpCode.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the full 6-digit OTP code')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;

    final isValid = _otpCode == staticOtp || _otpCode == legacyStaticOtp;

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
            : 'Invalid OTP code. Please try again.';
      });
      if (!_isLockedOut) {
        _focusNodes.first.requestFocus();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorText!),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = false;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoleSelectionScreen(phoneNumber: widget.phoneNumber),
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
