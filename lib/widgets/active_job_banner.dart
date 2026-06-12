import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/colors.dart';
import '../core/router/app_router.dart';
import '../core/services/service_providers.dart';

class ActiveJobBanner extends ConsumerWidget {
  final String role; // 'client' or 'worker'

  const ActiveJobBanner({super.key, required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: role == 'client'
          ? FirebaseFirestore.instance
              .collection('jobs')
              .where('client_id', isEqualTo: user.uid)
              .where('status', whereIn: ['assigned', 'in_progress'])
              .limit(1)
              .snapshots()
          : FirebaseFirestore.instance
              .collection('jobs')
              .where('worker_id', isEqualTo: user.uid)
              .where('status', whereIn: ['assigned', 'in_progress'])
              .limit(1)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final jobDoc = snapshot.data!.docs.first;
        final jobId = jobDoc.id;
        final jobData = jobDoc.data() as Map<String, dynamic>;
        final category = jobData['category'] ?? 'Job';

        return GestureDetector(
          onTap: () {
            if (role == 'client') {
              context.push(AppRouter.liveTracking, extra: jobId);
            } else {
              context.push(AppRouter.workerTracking, extra: jobId);
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.9),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Active Job in Progress',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        category,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'VIEW TRACKING',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
