import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/service_providers.dart';
import '../widgets/auth_widgets.dart';

class WorkerSignupScreen extends ConsumerStatefulWidget {
  const WorkerSignupScreen({super.key});

  @override
  ConsumerState<WorkerSignupScreen> createState() => _WorkerSignupScreenState();
}

class _WorkerSignupScreenState extends ConsumerState<WorkerSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _experienceController = TextEditingController();
  final _cnicController = TextEditingController();
  final List<String> _selectedCategories = [];
  bool _isLoading = false;
  bool _obscurePassword = true;
  
  XFile? _cnicFront;
  XFile? _cnicBack;
  final ImagePicker _picker = ImagePicker();

  final List<String> _allCategories = [
    'Fan Installation',
    'Plumbing',
    'Electrician',
    'AC Repair',
    'Cleaning',
    'Carpentry',
    'Painting',
    'Gardening'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _experienceController.dispose();
    _cnicController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isFront) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        if (isFront) {
          _cnicFront = image;
        } else {
          _cnicBack = image;
        }
      });
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one category')),
      );
      return;
    }

    if (_cnicFront == null || _cnicBack == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload both Front and Back of CNIC')),
      );
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final experience = _experienceController.text.trim();
    final cnic = _cnicController.text.trim();

    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      
      // Switching to Email OTP as requested
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
              'role': 'worker',
              'extraData': {
                'categories': _selectedCategories,
                'experience': experience,
                'cnic': cnic,
                'cnic_front_path': _cnicFront!.path,
                'cnic_back_path': _cnicBack!.path,
                'bio': 'New worker on KamKaj',
                'is_approved': false,
              },
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
                'Create Worker Account',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Join our community of skilled professionals',
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
                    const SizedBox(height: 16),
                    AuthTextField(
                      hintText: 'CNIC Number (e.g., 42101-1234567-1)',
                      controller: _cnicController,
                      prefixIcon: const Icon(Icons.badge_outlined),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter CNIC';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Upload CNIC Photos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _ImagePickerBox(
                            label: 'Front Side',
                            image: _cnicFront,
                            onTap: () => _pickImage(true),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _ImagePickerBox(
                            label: 'Back Side',
                            image: _cnicBack,
                            onTap: () => _pickImage(false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    AuthTextField(
                      hintText: 'Experience (Years)',
                      controller: _experienceController,
                      prefixIcon: const Icon(Icons.work_outline),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter experience';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Select Categories', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _allCategories.map((category) {
                  final isSelected = _selectedCategories.contains(category);
                  return FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedCategories.add(category);
                        } else {
                          _selectedCategories.remove(category);
                        }
                      });
                    },
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _signUp,
                      child: const Text('SIGN UP'),
                    ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account? "),
                  GestureDetector(
                    onTap: () => context.push(AppRouter.workerLogin),
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
              const Text('Worker Signup', style: TextStyle(color: AppColors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePickerBox extends StatelessWidget {
  final String label;
  final XFile? image;
  final VoidCallback onTap;

  const _ImagePickerBox({
    required this.label,
    required this.image,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.lightGrey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.lightGrey),
            ),
            child: image == null
                ? const Icon(Icons.add_a_photo, color: AppColors.primary, size: 32)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(File(image!.path), fit: BoxFit.cover),
                  ),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.grey)),
        ],
      ),
    );
  }
}
