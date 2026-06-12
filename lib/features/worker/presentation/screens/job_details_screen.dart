import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/router/app_router.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/service_providers.dart';

class JobDetailsScreen extends ConsumerWidget {
  final String jobId;
  final Map<String, dynamic> jobData;

  const JobDetailsScreen({
    super.key,
    required this.jobId,
    required this.jobData,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(jobData['category'] ?? 'Job', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text('Rs. ${jobData['budget']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              jobData['description'] ?? 'No description provided.',
              style: const TextStyle(color: AppColors.grey),
            ),
            const SizedBox(height: 24),
            const Text('Location', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              jobData['location_name'] ?? 'No location provided.',
              style: const TextStyle(color: AppColors.grey),
            ),
            const SizedBox(height: 48),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.push(AppRouter.placeBid, extra: jobId),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('BID ON JOB'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final workerId = ref.read(authServiceProvider).currentUser?.uid;
                      if (workerId != null) {
                        await ref.read(jobServiceProvider).assignWorker(jobId, workerId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job accepted!')));
                          context.go(AppRouter.workerTracking, extra: jobId);
                        }
                      }
                    },
                    child: const Text('ACCEPT NOW'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
