import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/service_providers.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Admin Dashboard', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w900)),
          backgroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.grey,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
            tabs: [
              Tab(text: 'PENDING'),
              Tab(text: 'APPROVED'),
            ],
          ),
          actions: [
            FutureBuilder(
              future: ref.read(adminServiceProvider).getPendingCNICs(),
              builder: (context, snapshot) {
                final isOnline = snapshot.connectionState != ConnectionState.none && !snapshot.hasError;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Tooltip(
                    message: isOnline ? 'Backend Online' : 'Backend Offline',
                    child: Icon(
                      Icons.circle,
                      size: 12,
                      color: isOnline ? Colors.green : Colors.red,
                    ),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: AppColors.secondary),
              onPressed: () async {
                await ref.read(authServiceProvider).signOut();
                if (context.mounted) {
                  context.go(AppRouter.roleSelection);
                }
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _WorkerList(isPending: true),
            _WorkerList(isPending: false),
          ],
        ),
      ),
    );
  }
}

class _WorkerList extends ConsumerStatefulWidget {
  final bool isPending;
  const _WorkerList({required this.isPending});

  @override
  ConsumerState<_WorkerList> createState() => _WorkerListState();
}

class _WorkerListState extends ConsumerState<_WorkerList> {
  String? _processingWorkerId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'worker')
          .where('is_approved', isEqualTo: !widget.isPending)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final workers = snapshot.data?.docs ?? [];
        if (workers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline_rounded, size: 64, color: AppColors.grey.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text(
                  widget.isPending ? 'No pending registrations' : 'No approved workers yet',
                  style: const TextStyle(color: AppColors.grey, fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: workers.length,
          itemBuilder: (context, index) {
            final worker = workers[index].data() as Map<String, dynamic>;
            final workerId = workers[index].id;
            final isProcessing = _processingWorkerId == workerId;

            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: ExpansionTile(
                  backgroundColor: Colors.white,
                  collapsedBackgroundColor: Colors.white,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: const Icon(Icons.person_rounded, color: AppColors.primary),
                  ),
                  title: Text(
                    worker['full_name'] ?? 'N/A',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.secondary),
                  ),
                  subtitle: Text(
                    worker['email'] ?? 'N/A',
                    style: const TextStyle(color: AppColors.grey, fontSize: 12),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(height: 32),
                          _InfoRow(label: 'CNIC Number', value: worker['cnic'] ?? 'N/A'),
                          _InfoRow(label: 'Experience', value: '${worker['experience'] ?? 0} Years'),
                          _InfoRow(label: 'Phone', value: worker['phone'] ?? 'N/A'),
                          const SizedBox(height: 20),
                          const Text('SKILLS & CATEGORIES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.grey, letterSpacing: 1)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ((worker['categories'] as List?) ?? []).map((c) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(c, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                            )).toList(),
                          ),
                          const SizedBox(height: 24),
                          const Text('CNIC VERIFICATION DOCUMENTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.grey, letterSpacing: 1)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _CnicPreview(
                                  label: 'FRONT SIDE',
                                  imageUrl: worker['cnic_front_url'],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _CnicPreview(
                                  label: 'BACK SIDE',
                                  imageUrl: worker['cnic_back_url'],
                                ),
                              ),
                            ],
                          ),
                          if (widget.isPending) ...[
                            const SizedBox(height: 32),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: isProcessing
                                        ? null
                                        : () async {
                                            setState(() => _processingWorkerId = workerId);
                                            try {
                                              // Try backend first, but if it fails, still update Firestore
                                              try {
                                                await ref.read(adminServiceProvider).verifyWorker(workerId, 'rejected', reason: 'Identity verification failed');
                                              } catch (e) {
                                                debugPrint('Backend call failed, but proceeding with Firestore update: $e');
                                              }
                                              // Always update Firestore
                                              await ref.read(authServiceProvider).rejectWorker(workerId);
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Worker rejected successfully')),
                                                );
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Failed to reject worker: ${e.toString()}')),
                                                );
                                              }
                                            } finally {
                                              if (mounted) {
                                                setState(() => _processingWorkerId = null);
                                              }
                                            }
                                          },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                      minimumSize: const Size(0, 52),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    child: isProcessing
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2),
                                          )
                                        : const Text('REJECT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: isProcessing
                                        ? null
                                        : () async {
                                            setState(() => _processingWorkerId = workerId);
                                            try {
                                              // Try backend first, but if it fails, still update Firestore
                                              try {
                                                await ref.read(adminServiceProvider).verifyWorker(workerId, 'approved');
                                              } catch (e) {
                                                debugPrint('Backend call failed, but proceeding with Firestore update: $e');
                                              }
                                              // Always update Firestore
                                              await ref.read(authServiceProvider).approveWorker(workerId);
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Worker approved successfully')),
                                                );
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Failed to approve worker: ${e.toString()}')),
                                                );
                                              }
                                            } finally {
                                              if (mounted) {
                                                setState(() => _processingWorkerId = null);
                                              }
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(0, 52),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      elevation: 0,
                                    ),
                                    child: isProcessing
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                          )
                                        : const Text('APPROVE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CnicPreview extends StatelessWidget {
  final String label;
  final String? imageUrl;
  const _CnicPreview({required this.label, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.grey)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () {
            if (imageUrl != null) {
              showDialog(
                context: context,
                builder: (context) => Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.all(10),
                  child: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(imageUrl!, fit: BoxFit.contain),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 32),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              );
            }
          },
          child: Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.lightGrey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.lightGrey.withValues(alpha: 0.5)),
            ),
            child: imageUrl == null
                ? const Icon(Icons.image_not_supported_rounded, color: AppColors.grey)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.error_outline),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.grey, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.secondary)),
        ],
      ),
    );
  }
}
