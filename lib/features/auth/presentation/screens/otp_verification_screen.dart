import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/service_providers.dart';

class OTPVerificationScreen extends ConsumerStatefulWidget {
  final String? phoneNumber;
  final String? email;
  final String? verificationId;
  final Map<String, dynamic>? userData;

  const OTPVerificationScreen({
    super.key,
    this.phoneNumber,
    this.email,
    this.verificationId,
    this.userData,
  });

  @override
  ConsumerState<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends ConsumerState<OTPVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  bool _isLoading = false;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _controllers.map((c) => c.text).join();
    if (code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the full 6-digit code')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      
      if (widget.email != null) {
        // --- Email OTP Logic ---
        final isValid = await authService.verifyEmailOTP(widget.email!, code);
        if (isValid) {
          // Proceed with account creation
          await authService.signUp(
            email: widget.userData!['email'],
            password: widget.userData!['password'],
            fullName: widget.userData!['fullName'],
            phone: widget.userData!['phone'] ?? '',
            role: widget.userData!['role'],
            extraData: widget.userData!['extraData'],
          );
          _navigateToHome(widget.userData!['role']);
        } else {
          throw Exception('Invalid or expired OTP code');
        }
      } else if (widget.verificationId != null) {
        // --- Phone OTP Logic ---
        final userCredential = await authService.signInWithPhone(
              widget.verificationId!,
              code,
            );

        if (widget.userData != null && userCredential.user != null) {
          await authService.signUp(
            email: widget.userData!['email'],
            password: widget.userData!['password'],
            fullName: widget.userData!['fullName'],
            phone: widget.phoneNumber!,
            role: widget.userData!['role'],
            extraData: widget.userData!['extraData'],
          );
        }
        _navigateToHome(widget.userData?['role'] ?? 'client');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToHome(String role) {
    if (role == 'worker') {
      // After signup/verification, workers must wait for admin approval
      context.go(AppRouter.pendingApproval);
    } else {
      context.go(AppRouter.clientHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.email ?? widget.phoneNumber ?? 'your device';
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton(color: Colors.black)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.handyman, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text(
                'KAMKAJ',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              const Text(
                'OTP Verification',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the 6-digit code sent to $target',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.grey),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  6,
                  (index) => Flexible(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: TextField(
                        controller: _controllers[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        decoration: InputDecoration(
                          counterText: '',
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppColors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppColors.primary),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty && index < 5) {
                            FocusScope.of(context).nextFocus();
                          } else if (value.isEmpty && index > 0) {
                            FocusScope.of(context).previousFocus();
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _verify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('VERIFY'),
                    ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  // Resend code logic could be added here
                },
                child: const Text(
                  'Didn\'t receive code? Resend',
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
