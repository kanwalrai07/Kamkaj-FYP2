import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/service_providers.dart';
import '../../../../core/router/app_router.dart';
import 'role_selection_screen.dart';

class RootScreen extends ConsumerWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return const RoleSelectionScreen();
        }
        
        // Use a FutureBuilder or a separate provider to fetch user role and redirect
        return FutureBuilder<DocumentSnapshot>(
          future: ref.read(authServiceProvider).getUserProfile(user.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasData && snapshot.data!.exists) {
              final userData = snapshot.data!.data() as Map<String, dynamic>;
              final role = userData['role'] as String?;
              final isApproved = userData['is_approved'] ?? false;
              
              // Schedule redirection after build
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (role == 'client') {
                  context.go(AppRouter.clientHome);
                } else if (role == 'worker') {
                  if (isApproved) {
                    context.go(AppRouter.workerDashboard);
                  } else {
                    context.go(AppRouter.pendingApproval);
                  }
                } else {
                  context.go(AppRouter.roleSelection);
                }
              });
            } else {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.go(AppRouter.roleSelection);
              });
            }
            
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          },
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        body: Center(child: Text('Error: $err')),
      ),
    );
  }
}
