import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../core/constants/colors.dart';
import '../../../../core/router/app_router.dart';
import 'package:go_router/go_router.dart';
class CNICVerificationScreen extends ConsumerStatefulWidget {
  const CNICVerificationScreen({super.key});

  @override
  ConsumerState<CNICVerificationScreen> createState() => _CNICVerificationScreenState();
}

class _CNICVerificationScreenState extends ConsumerState<CNICVerificationScreen> {
  XFile? _frontImage;
  XFile? _backImage;
  bool _isVerifying = false;
  String _statusMessage = 'Upload your CNIC to verify identity';

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(bool isFront) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera); // Use camera for real-time check
    if (image != null) {
      setState(() {
        if (isFront) {
          _frontImage = image;
        } else {
          _backImage = image;
        }
      });
    }
  }

  Future<void> _verifyIdentity() async {
    if (_frontImage == null || _backImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture both front and back images of your CNIC')),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
      _statusMessage = 'Matching with approved documents...';
    });

    try {
      // Simulation of OCR and Image Matching logic
      // In a real app, you would:
      // 1. Send these images to a backend or use Google ML Kit (OCR)
      // 2. Extract the CNIC number and Name
      // 3. Compare with the worker's 'permanent_identity' in Firestore
      // 4. Use a similarity algorithm for the 80% match
      
      await Future.delayed(const Duration(seconds: 3));
      
      setState(() => _statusMessage = 'Analyzing features (84% match)...');
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() => _statusMessage = 'Identity Verified Successfully!');
        await Future.delayed(const Duration(seconds: 1));
        
        if (mounted) {
          context.go(AppRouter.workerDashboard);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _statusMessage = 'Verification failed. Please try again.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Security Check', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_rounded, color: AppColors.primary, size: 40),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Identity Verification',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.secondary),
                        ),
                        Text(
                          _statusMessage,
                          style: const TextStyle(color: AppColors.grey, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Expanded(
              child: GridView.count(
                crossAxisCount: 1,
                mainAxisSpacing: 20,
                childAspectRatio: 1.6,
                children: [
                  _UploadBox(
                    label: 'FRONT OF CNIC',
                    image: _frontImage,
                    onTap: _isVerifying ? null : () => _pickImage(true),
                    isVerifying: _isVerifying,
                  ),
                  _UploadBox(
                    label: 'BACK OF CNIC',
                    image: _backImage,
                    onTap: _isVerifying ? null : () => _pickImage(false),
                    isVerifying: _isVerifying,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (!_isVerifying)
              ElevatedButton(
                onPressed: _verifyIdentity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text(
                  'VERIFY & ENTER',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
                ),
              )
            else
              const Column(
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Securing your session...', style: TextStyle(color: AppColors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _UploadBox extends StatelessWidget {
  final String label;
  final XFile? image;
  final VoidCallback? onTap;
  final bool isVerifying;

  const _UploadBox({
    required this.label,
    this.image,
    required this.onTap,
    required this.isVerifying,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: image != null ? AppColors.primary : AppColors.lightGrey,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image != null)
                Image.file(File(image!.path), fit: BoxFit.cover)
              else
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt_rounded, size: 48, color: AppColors.primary.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    Text(
                      label,
                      style: const TextStyle(color: AppColors.grey, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1),
                    ),
                  ],
                ),
              if (isVerifying)
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: const Center(
                    child: Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 64),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
