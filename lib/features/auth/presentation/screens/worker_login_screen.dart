import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/service_providers.dart';
import '../widgets/auth_widgets.dart';

class WorkerLoginScreen extends ConsumerStatefulWidget {
  const WorkerLoginScreen({super.key});

  @override
  ConsumerState<WorkerLoginScreen> createState() => _WorkerLoginScreenState();
}

class _WorkerLoginScreenState extends ConsumerState<WorkerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userCredential = await ref.read(authServiceProvider).signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      if (mounted && userCredential.user != null) {
        final userDoc = await ref.read(authServiceProvider).getUserProfile(userCredential.user!.uid);
        final userData = userDoc.data() as Map<String, dynamic>?;
        
        if (userData != null && userData['role'] == 'worker') {
          if (userData['is_approved'] == false) {
            if (mounted) context.go(AppRouter.pendingApproval);
          } else {
            // New Requirement: Verified workers must re-verify CNIC to enter home
            if (mounted) context.go(AppRouter.cnicVerification);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
              const Text(
                'Your Work, Our Way',
                style: TextStyle(fontSize: 12, color: AppColors.grey),
              ),
              const SizedBox(height: 40),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Welcome Back!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Please sign in to your account',
                  style: TextStyle(color: AppColors.grey),
                ),
              ),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Column(
                  children: [
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
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push(AppRouter.resetPassword),
                  child: const Text('Forgot Password?'),
                ),
              ),
              const SizedBox(height: 16),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _signIn,
                      child: const Text('LOGIN'),
                    ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? "),
                  GestureDetector(
                    onTap: () => context.push(AppRouter.workerSignup),
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Worker Login', style: TextStyle(color: AppColors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
