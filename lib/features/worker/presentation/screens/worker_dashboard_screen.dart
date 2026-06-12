import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/service_providers.dart';

class WorkerDashboardScreen extends ConsumerStatefulWidget {
  const WorkerDashboardScreen({super.key});

  @override
  ConsumerState<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends ConsumerState<WorkerDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authServiceProvider).currentUser;
    final userName = user?.displayName?.split(' ').first ?? 'Worker';

    return Column(
      children: [
        // Premium Header
        Container(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assalam-o-Alaikum, $userName!',
                style: const TextStyle(fontSize: 14, color: AppColors.grey, fontWeight: FontWeight.w500),
              ),
              const Text(
                'Find Your Next Job',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.secondary),
              ),
            ],
          ),
        ),

        // Custom Tab Bar
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.grey,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: const [
              Tab(text: 'SERVICES'),
              Tab(text: 'REQUESTS'),
              Tab(text: 'ACTIVE'),
            ],
          ),
        ),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _NewJobsList(),
              _BiddedJobsList(workerId: user?.uid ?? ''),
              _InProgressJobsList(),
            ],
          ),
        ),
      ],
    );
  }
}

class _BiddedJobsList extends ConsumerWidget {
  final String workerId;
  const _BiddedJobsList({required this.workerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<QuerySnapshot>(
      stream: ref.watch(jobServiceProvider).getBiddedJobs(workerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final jobs = snapshot.data?.docs ?? [];
        if (jobs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.assignment_outlined,
            title: 'No active bids',
            subtitle: 'Jobs you bid on will appear here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: jobs.length,
          itemBuilder: (context, index) {
            final job = jobs[index].data() as Map<String, dynamic>;
            final jobId = jobs[index].id;
            return _buildJobCard(
              context: context,
              job: job,
              jobId: jobId,
              statusText: 'BID PLACED',
              statusColor: AppColors.primary,
              buttonText: 'VIEW DETAILS',
              onTap: () => context.push(AppRouter.jobDetails, extra: {'jobId': jobId, 'jobData': job}),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: AppColors.grey.withValues(alpha: 0.2)),
          const SizedBox(height: 24),
          Text(title, style: const TextStyle(color: AppColors.secondary, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: AppColors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildJobCard({
    required BuildContext context,
    required Map<String, dynamic> job,
    required String jobId,
    required String statusText,
    required Color statusColor,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
        border: Border.all(color: AppColors.lightGrey.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                job['category'] ?? 'Job',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.secondary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            job['description'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: statusColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: Text(
              buttonText,
              style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewJobsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<QuerySnapshot>(
      stream: ref.watch(jobServiceProvider).getAvailableJobs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final jobs = snapshot.data?.docs ?? [];
        if (jobs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.search_off_rounded,
            title: 'No jobs available',
            subtitle: 'Keep checking for new opportunities!',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: jobs.length,
          itemBuilder: (context, index) {
            final job = jobs[index].data() as Map<String, dynamic>;
            final jobId = jobs[index].id;
            return _buildJobCard(
              context: context,
              job: job,
              jobId: jobId,
              statusText: 'NEW',
              statusColor: Colors.green,
              buttonText: 'VIEW DETAILS',
              onTap: () => context.push(AppRouter.jobDetails, extra: {'jobId': jobId, 'jobData': job}),
            );
          },
        );
      },
    );
  }
}

class _InProgressJobsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .where('worker_id', isEqualTo: user.uid)
          .where('status', isEqualTo: 'assigned')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final jobs = snapshot.data?.docs ?? [];
        if (jobs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.directions_run_rounded,
            title: 'No active jobs',
            subtitle: 'Jobs you are working on will appear here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: jobs.length,
          itemBuilder: (context, index) {
            final job = jobs[index].data() as Map<String, dynamic>;
            final jobId = jobs[index].id;
            return _buildJobCard(
              context: context,
              job: job,
              jobId: jobId,
              statusText: 'ACTIVE',
              statusColor: Colors.orange,
              buttonText: 'TRACK & CHAT',
              onTap: () => context.push(AppRouter.workerTracking, extra: jobId),
            );
          },
        );
      },
    );
  }
}

Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 80, color: AppColors.grey.withValues(alpha: 0.2)),
        const SizedBox(height: 24),
        Text(title, style: const TextStyle(color: AppColors.secondary, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(subtitle, style: const TextStyle(color: AppColors.grey, fontSize: 14)),
      ],
    ),
  );
}

Widget _buildJobCard({
  required BuildContext context,
  required Map<String, dynamic> job,
  required String jobId,
  required String statusText,
  required Color statusColor,
  required String buttonText,
  required VoidCallback onTap,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 20),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
      border: Border.all(color: AppColors.lightGrey.withValues(alpha: 0.5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              job['category'] ?? 'Job',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.secondary),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                statusText,
                style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          job['description'] ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.location_on_rounded, size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                job['location_name'] ?? 'Islamabad',
                style: const TextStyle(color: AppColors.secondary, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              'Rs. ${job['budget'] ?? job['final_price'] ?? 0}',
              style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: statusColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: Text(
            buttonText,
            style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
        ),
      ],
    ),
  );
}
