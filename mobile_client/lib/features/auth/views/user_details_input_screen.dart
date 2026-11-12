import 'package:flutter/material.dart';
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

  void _onContinue() {
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                const Text(
                  'enter your full name',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _nameController,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'full name',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(40),
                      borderSide: const BorderSide(color: Colors.black, width: 2.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(40),
                      borderSide: const BorderSide(color: Colors.black, width: 2.4),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(40),
                      borderSide: const BorderSide(color: Colors.red, width: 1.8),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(40),
                      borderSide: const BorderSide(color: Colors.red, width: 2.0),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'please enter your name';
                    }
                    if (value.trim().split(' ').length < 2) {
                      return 'please enter first and last name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 200,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _onContinue,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.black, width: 2.0),
                      shape: const StadiumBorder(),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                    ),
                    child: const Text(
                      'continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
