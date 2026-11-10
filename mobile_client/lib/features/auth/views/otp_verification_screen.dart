import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;

  // Rate Limiting & Cooldown Protection (Pillar 4 Security)
  int _resendCountdown = 60;
  int _remainingAttempts = 3;
  bool _isLockedOut = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdownTimer();
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
      node.dispose();
    }
    super.dispose();
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  void _autoFillTestOtp() {
    const demoOtp = '202601';
    for (int i = 0; i < demoOtp.length; i++) {
      _controllers[i].text = demoOtp[i];
    }
    setState(() {});
    _verifyOtp();
  }

  void _resendOtp() {
    if (_resendCountdown > 0 || _isLockedOut) return;
    _startCountdownTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Simulated OTP resent to ${widget.phoneNumber} (60s cooldown active).',
        ),
      ),
    );
  }

  void _verifyOtp() async {
    if (_isLockedOut) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account locked: 3 failed attempts. Cooldown active to prevent toll-fraud.'),
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
    });

    // Simulate OTP Verification Network Request
    await Future.delayed(const Duration(milliseconds: 750));

    if (!mounted) return;

    // In simulation mode (Dedicated Philippine SMS held), accept 202601 or any code starting with 2
    final isValid = _otpCode == '202601' || _otpCode.startsWith('2');

    if (!isValid) {
      setState(() {
        _isLoading = false;
        _remainingAttempts--;
        if (_remainingAttempts <= 0) {
          _isLockedOut = true;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isLockedOut
                ? 'Maximum 3 attempts exceeded. Account verification locked.'
                : 'Invalid OTP. Demo OTP is 202601. $_remainingAttempts attempts remaining.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = false;
    });

    // Navigate to Role Selection Screen
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
      appBar: AppBar(
        title: const Text('Verify Mobile Number'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                'Enter 6-Digit Code',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                  children: [
                    const TextSpan(text: 'We sent a verification code to '),
                    TextSpan(
                      text: widget.phoneNumber,
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Philippine SMS Simulation / Hold Notice Banner (Pillar 4)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.mark_chat_read_rounded, size: 16, color: Colors.blue.shade800),
                        const SizedBox(width: 6),
                        Text(
                          'Philippine SMS Gateway: Simulation Mode',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Dedicated SMS provider held. Use demo OTP: 202601 or tap below for rapid testing.',
                      style: TextStyle(fontSize: 11, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _autoFillTestOtp,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade900,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '⚡ Auto-Fill Test OTP (202601)',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              // 6 Digit Pin Code Fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  6,
                  (index) => SizedBox(
                    width: 45,
                    height: 55,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(1),
                      ],
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 5) {
                          _focusNodes[index + 1].requestFocus();
                        } else if (value.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                        if (_otpCode.length == 6) {
                          _verifyOtp();
                        }
                      },
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.zero,
                        counterText: '',
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.blue.shade900, width: 2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Attempts Remaining & Cooldown Timer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Attempts left: $_remainingAttempts/3',
                    style: TextStyle(
                      fontSize: 12,
                      color: _remainingAttempts == 1 ? Colors.red : Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  _resendCountdown > 0
                      ? Text(
                          'Resend in ${_resendCountdown}s',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        )
                      : TextButton(
                          onPressed: _isLockedOut ? null : _resendOtp,
                          child: const Text(
                            'Resend Code',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                ],
              ),

              const Spacer(),

              // Verify Button
              ElevatedButton(
                onPressed: _isLoading || _isLockedOut ? null : _verifyOtp,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(_isLockedOut ? 'Account Locked' : 'Verify Code'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
