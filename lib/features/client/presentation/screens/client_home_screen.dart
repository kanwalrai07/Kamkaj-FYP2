import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/service_providers.dart';

class ClientHomeScreen extends ConsumerStatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  ConsumerState<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends ConsumerState<ClientHomeScreen> with SingleTickerProviderStateMixin {
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
    final userName = user?.displayName?.split(' ').first ?? 'User';

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
                'Har Kaam Ka Hal',
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
              _buildHomeTab(context, user),
              _buildRequestsTab(user?.uid ?? ''),
              _buildActiveJobsTab(user?.uid ?? ''),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHomeTab(BuildContext context, dynamic user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          const SizedBox(height: 32),
          _buildPopularServicesHeader(),
          const SizedBox(height: 16),
          _buildServiceGrid(context),
          const SizedBox(height: 32),
          _buildCustomTaskBanner(context),
        ],
      ),
    );
  }

  Widget _buildRequestsTab(String clientId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .where('client_id', isEqualTo: clientId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        final jobs = snapshot.data?.docs ?? [];
        if (jobs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.assignment_outlined,
            title: 'No pending requests',
            subtitle: 'Post a job to get bids from workers',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: jobs.length,
          itemBuilder: (context, index) {
            final job = jobs[index].data() as Map<String, dynamic>;
            final jobId = jobs[index].id;
            return _buildJobCard(
              job: job,
              jobId: jobId,
              isPending: true,
              onTap: () => context.push(AppRouter.reviewBids, extra: jobId),
            );
          },
        );
      },
    );
  }

  Widget _buildActiveJobsTab(String clientId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .where('client_id', isEqualTo: clientId)
          .where('status', whereIn: ['assigned', 'in_progress'])
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        final jobs = snapshot.data?.docs ?? [];
        if (jobs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.directions_run_rounded,
            title: 'No active jobs',
            subtitle: 'Jobs in progress will appear here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: jobs.length,
          itemBuilder: (context, index) {
            final job = jobs[index].data() as Map<String, dynamic>;
            final jobId = jobs[index].id;
            return _buildJobCard(
              job: job,
              jobId: jobId,
              isPending: false,
              onTap: () => context.push(AppRouter.liveTracking, extra: jobId),
            );
          },
        );
      },
    );
  }

  Widget _buildJobCard({
    required Map<String, dynamic> job,
    required String jobId,
    required bool isPending,
    required VoidCallback onTap,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, 20 * (1 - value)), child: child),
        );
      },
      child: Container(
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
                if (isPending)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('jobs').doc(jobId).collection('bids').snapshots(),
                    builder: (context, bidSnap) {
                      final count = bidSnap.data?.docs.length ?? 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count BIDS',
                          style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                      );
                    },
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
                        SizedBox(width: 4),
                        Text('ASSIGNED', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w900)),
                      ],
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
                Expanded(
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPending ? AppColors.primary : Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                      isPending ? 'VIEW BIDS' : 'TRACK WORKER',
                      style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                  ),
                ),
                if (!isPending) ...[
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () async {
                      final navigator = context.push;
                      await ref.read(jobServiceProvider).completeJob(jobId);
                      if (context.mounted) {
                        navigator(AppRouter.rateWorker, extra: job['worker_id']);
                      }
                    },
                    icon: const Icon(Icons.done_all_rounded, color: Colors.green),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.green.withValues(alpha: 0.1),
                      padding: const EdgeInsets.all(14),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
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

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search for services...',
          hintStyle: const TextStyle(color: AppColors.grey, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
          fillColor: Colors.white,
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _buildPopularServicesHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Popular Services', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.secondary)),
        TextButton(onPressed: () {}, child: const Text('See All', style: TextStyle(fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _buildCustomTaskBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF1E3A8A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Got a custom task?', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('Post it as an ad and get bids from workers!', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: () => context.push(AppRouter.postJob),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: const Text('POST A JOB', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceGrid(BuildContext context) {
    final services = [
      {'name': 'Plumbing', 'icon': Icons.plumbing_rounded, 'color': Colors.blue},
      {'name': 'Electrician', 'icon': Icons.electrical_services_rounded, 'color': Colors.orange},
      {'name': 'Cleaning', 'icon': Icons.cleaning_services_rounded, 'color': Colors.green},
      {'name': 'AC Repair', 'icon': Icons.ac_unit_rounded, 'color': Colors.cyan},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.1),
      itemCount: services.length,
      itemBuilder: (context, index) {
        return InkWell(
          onTap: () => context.push(AppRouter.postJob),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 8))],
              border: Border.all(color: AppColors.lightGrey.withValues(alpha: 0.5)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: (services[index]['color'] as Color).withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(services[index]['icon'] as IconData, color: services[index]['color'] as Color, size: 32),
                ),
                const SizedBox(height: 12),
                Text(services[index]['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.secondary, fontSize: 15)),
              ],
            ),
          ),
        );
      },
    );
  }
}
