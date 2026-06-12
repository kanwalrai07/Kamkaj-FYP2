import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/service_providers.dart';
import '../../../../widgets/profile_field.dart';
import '../../../../features/auth/presentation/widgets/auth_widgets.dart';

class WorkerProfileScreen extends ConsumerStatefulWidget {
  const WorkerProfileScreen({super.key});

  @override
  ConsumerState<WorkerProfileScreen> createState() => _WorkerProfileScreenState();
}

class _WorkerProfileScreenState extends ConsumerState<WorkerProfileScreen> {
  bool _isUploading = false;

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 512,
    );

    if (image != null) {
      setState(() => _isUploading = true);
      try {
        final user = ref.read(authServiceProvider).currentUser;
        if (user != null) {
          final imageUrl = await ref.read(storageServiceProvider).uploadProfileImage(
                userId: user.uid,
                file: File(image.path),
              );

          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'profile_image': imageUrl,
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile image updated successfully!'))
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload image: $e'))
          );
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _editField(String label, String key, String currentValue, {bool isNumeric = false, bool isName = false}) async {
    final controller = TextEditingController(text: currentValue);
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $label'),
        content: Form(
          key: formKey,
          child: AuthTextField(
            hintText: 'Enter $label',
            controller: controller,
            keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
            inputFormatters: [
              if (isNumeric) FilteringTextInputFormatter.digitsOnly,
              if (isNumeric && key == 'phone') LengthLimitingTextInputFormatter(11),
              if (isName) FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
            ],
            validator: (value) {
              if (value == null || value.isEmpty) return 'Cannot be empty';
              if (key == 'phone' && value.length < 10) return 'Too short';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final newValue = controller.text.trim();
                final user = ref.read(authServiceProvider).currentUser;
                if (user != null) {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);

                  await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                    key: newValue,
                  });
                  
                  if (mounted) {
                    messenger.showSnackBar(const SnackBar(content: Text('Profile updated!')));
                    navigator.pop();
                  }
                }
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authServiceProvider).currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Worker Profile', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: user == null
          ? const Center(child: Text('Please log in'))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                final profileImage = userData['profile_image'] as String?;

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(32),
                            bottomRight: Radius.circular(32),
                          ),
                        ),
                        padding: const EdgeInsets.only(bottom: 32, top: 8),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.1), width: 8),
                                  ),
                                  child: CircleAvatar(
                                    radius: 60,
                                    backgroundColor: AppColors.lightGrey,
                                    backgroundImage: profileImage != null ? NetworkImage(profileImage) : null,
                                    child: profileImage == null
                                        ? const Icon(Icons.person, size: 60, color: AppColors.grey)
                                        : null,
                                  ),
                                ),
                                if (_isUploading)
                                  const Positioned.fill(
                                    child: Center(child: CircularProgressIndicator()),
                                  ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: _isUploading ? null : _pickAndUploadImage,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              userData['full_name'] ?? 'Worker',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '${(userData['rating'] ?? 5.0).toStringAsFixed(1)} (${userData['review_count'] ?? 0} reviews)',
                                  style: const TextStyle(color: AppColors.grey, fontSize: 14),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            _buildSectionCard([
                              ProfileField(
                                label: 'Full Name',
                                value: userData['full_name'] ?? 'N/A',
                                isEditable: true,
                                onEdit: () => _editField('Full Name', 'full_name', userData['full_name'] ?? '', isName: true),
                              ),
                              const Divider(height: 32),
                              ProfileField(
                                label: 'Phone Number',
                                value: userData['phone'] ?? 'N/A',
                                isEditable: true,
                                onEdit: () => _editField('Phone Number', 'phone', userData['phone'] ?? '', isNumeric: true),
                              ),
                              const Divider(height: 32),
                              ProfileField(label: 'CNIC', value: userData['cnic'] ?? 'Not verified', isEditable: false),
                            ]),
                            const SizedBox(height: 24),
                            _buildSectionCard([
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatItem(
                                      'Ustaad Score',
                                      (userData['ustaad_score'] ?? 0.0).toString(),
                                      Icons.workspace_premium_rounded,
                                      AppColors.primary,
                                    ),
                                  ),
                                  Container(height: 40, width: 1, color: AppColors.lightGrey),
                                  Expanded(
                                    child: _buildStatItem(
                                      'Jobs Done',
                                      (userData['completed_jobs_count'] ?? 0).toString(),
                                      Icons.check_circle_rounded,
                                      Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ]),
                            const SizedBox(height: 24),
                            _buildSectionCard([
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Categories', style: TextStyle(fontSize: 12, color: AppColors.grey)),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      children: ((userData['categories'] as List?) ?? []).map((c) => Chip(
                                        label: Text(c, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                        side: BorderSide.none,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      )).toList(),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 32),
                              ProfileField(
                                label: 'Experience',
                                value: '${userData['experience'] ?? 0} Years',
                                isEditable: true,
                                onEdit: () => _editField('Experience', 'experience', userData['experience']?.toString() ?? '', isNumeric: true),
                              ),
                              const Divider(height: 32),
                              ProfileField(
                                label: 'Bio',
                                value: userData['bio'] ?? 'No bio yet',
                                isEditable: true,
                                onEdit: () => _editField('Bio', 'bio', userData['bio'] ?? ''),
                              ),
                            ]),
                            const SizedBox(height: 32),
                            OutlinedButton.icon(
                              onPressed: () async {
                                await ref.read(authServiceProvider).signOut();
                                if (context.mounted) {
                                  context.go(AppRouter.roleSelection);
                                }
                              },
                              icon: const Icon(Icons.logout, size: 18),
                              label: const Text('LOGOUT'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                minimumSize: const Size(double.infinity, 54),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSectionCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.grey)),
      ],
    );
  }
}
