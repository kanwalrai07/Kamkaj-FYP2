import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/service_providers.dart';

class ReviewBidsScreen extends ConsumerWidget {
  final String jobId;
  const ReviewBidsScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Bids', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Listen to job status changes
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('jobs').doc(jobId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                if (data['status'] == 'assigned' || data['status'] == 'in_progress') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) {
                      context.go(AppRouter.liveTracking, extra: jobId);
                    }
                  });
                }
              }
              return const SizedBox.shrink();
            },
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: ref.watch(jobServiceProvider).getJobBids(jobId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final bids = snapshot.data?.docs ?? [];
                if (bids.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Waiting for workers to bid...'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: bids.length,
                  itemBuilder: (context, index) {
                    final bid = bids[index].data() as Map<String, dynamic>;
                    final workerId = bid['worker_id'];

                    return FutureBuilder<DocumentSnapshot>(
                      future: ref.read(authServiceProvider).getUserProfile(workerId),
                      builder: (context, userSnapshot) {
                        final workerData = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
                        final workerName = workerData['full_name'] ?? 'Worker';
                        final workerRating = workerData['rating'] ?? 5.0;
                        final workerExp = workerData['experience'] ?? 'N/A';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.lightGrey),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                radius: 30,
                                backgroundColor: AppColors.primary,
                                child: Icon(Icons.person, color: Colors.white),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      workerName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    Row(
                                      children: [
                                        const Icon(Icons.star, color: Colors.amber, size: 14),
                                        Text(' $workerRating | Exp: $workerExp', style: const TextStyle(fontSize: 12, color: AppColors.grey)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(bid['message'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.grey)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Rs. ${bid['amount']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 18),
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      await ref.read(jobServiceProvider).assignWorker(
                                            jobId,
                                            workerId,
                                            price: (bid['amount'] as num).toDouble(),
                                          );
                                      if (context.mounted) {
                                        context.push(AppRouter.liveTracking, extra: jobId);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size(80, 36),
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                    ),
                                    child: const Text('SELECT', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
