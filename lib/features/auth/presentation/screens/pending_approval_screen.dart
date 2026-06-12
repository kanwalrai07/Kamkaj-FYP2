import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/service_providers.dart';

class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please login again')));
    }

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final isApproved = data['is_approved'] ?? false;

            if (isApproved) {
              // Use WidgetsBinding to avoid navigation during build
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.go(AppRouter.workerDashboard);
              });
            }
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified_user_outlined, size: 100, color: Colors.orange),
                  const SizedBox(height: 32),
                  const Text(
                    'Profile Under Review',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your worker profile has been submitted and is currently being reviewed by our admin team. This usually takes 24-48 hours.',
                    style: TextStyle(color: AppColors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  const CircularProgressIndicator(color: Colors.orange),
                  const SizedBox(height: 48),
                  OutlinedButton(
                    onPressed: () async {
                      await ref.read(authServiceProvider).signOut();
                      if (context.mounted) {
                        context.go(AppRouter.roleSelection);
                      }
                    },
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                    child: const Text('LOGOUT'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
