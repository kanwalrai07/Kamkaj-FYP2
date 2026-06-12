import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/service_providers.dart';
import '../widgets/auth_widgets.dart';

class ClientSignupScreen extends ConsumerStatefulWidget {
  const ClientSignupScreen({super.key});

  @override
  ConsumerState<ClientSignupScreen> createState() => _ClientSignupScreenState();
}

class _ClientSignupScreenState extends ConsumerState<ClientSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);

      // Since Play Integrity is failing, we switch to Email OTP flow
      await authService.sendEmailOTP(email);

      if (mounted) {
        setState(() => _isLoading = false);
        context.push(
          AppRouter.otpVerification,
          extra: {
            'email': email,
            'userData': {
              'email': email,
              'password': password,
              'fullName': name,
              'phone': phone,
              'role': 'client',
            },
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithGoogle(role: 'client');
      if (mounted) {
        context.go(AppRouter.clientHome);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text(
                'Create Account',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const Text(
                'It\'s free and always will be',
                style: TextStyle(color: AppColors.grey),
              ),
              const SizedBox(height: 40),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    AuthTextField(
                      hintText: 'Full Name',
                      controller: _nameController,
                      prefixIcon: const Icon(Icons.person_outline),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter your name';
                        if (value.length < 3) return 'Name too short';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      hintText: 'Email',
                      controller: _emailController,
                      prefixIcon: const Icon(Icons.email_outlined),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter email';
                        if (!value.toLowerCase().endsWith('@gmail.com')) {
                          return 'Only @gmail.com addresses allowed';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      hintText: 'Phone Number (e.g. 03001234567)',
                      controller: _phoneController,
                      prefixIcon: const Icon(Icons.phone_outlined),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter phone number';
                        if (value.length < 10) return 'Phone number must be at least 10 digits';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      hintText: 'Password',
                      isPassword: true,
                      obscureText: _obscurePassword,
                      controller: _passwordController,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter password';
                        if (value.length < 6) return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _signUp,
                      child: const Text('CREATE ACCOUNT'),
                    ),
              const SizedBox(height: 24),
              const Text('Sign up with Google', style: TextStyle(color: AppColors.grey)),
              const SizedBox(height: 16),
              SocialSignInButton(
                label: 'Sign up with Google',
                onTap: _signInWithGoogle,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account? "),
                  GestureDetector(
                    onTap: () => context.push(AppRouter.clientLogin),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Client Signup', style: TextStyle(color: AppColors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
