import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/service_providers.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Please log in')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('jobs')
            .where(Filter.or(
              Filter('client_id', isEqualTo: user.uid),
              Filter('worker_id', isEqualTo: user.uid),
            ))
            .where('status', whereIn: ['assigned', 'in_progress', 'completed'])
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final jobs = snapshot.data?.docs ?? [];
          if (jobs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.primary.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No active messages',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Aap ke paas abhi koi messages nahi hain',
                    style: TextStyle(color: AppColors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: jobs.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final job = jobs[index].data() as Map<String, dynamic>;
              final jobId = jobs[index].id;
              final otherUserId = user.uid == job['client_id'] ? job['worker_id'] : job['client_id'];

              return _ChatTile(
                jobId: jobId,
                jobCategory: job['category'] ?? 'Job',
                otherUserId: otherUserId ?? '',
                currentUserId: user.uid,
              );
            },
          );
        },
      ),
    );
  }
}

class _ChatTile extends ConsumerWidget {
  final String jobId;
  final String jobCategory;
  final String otherUserId;
  final String currentUserId;

  const _ChatTile({
    required this.jobId,
    required this.jobCategory,
    required this.otherUserId,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
        final otherName = userData['full_name'] ?? 'User';

        return StreamBuilder<DatabaseEvent>(
          stream: FirebaseDatabase.instance.ref('chats/$jobId/last_message').onValue,
          builder: (context, msgSnap) {
            String lastMsg = 'Tap to start chatting';
            String timeStr = '';
            
            if (msgSnap.hasData && msgSnap.data!.snapshot.value != null) {
              final data = Map<String, dynamic>.from(msgSnap.data!.snapshot.value as Map);
              lastMsg = data['text'] ?? '';
              final timestamp = data['timestamp'] as int?;
              if (timestamp != null) {
                final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
                timeStr = DateFormat('hh:mm a').format(date);
              }
            }

            return ListTile(
              onTap: () => context.push(AppRouter.chatDetail, extra: jobId),
              leading: const CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.person, color: Colors.white, size: 30),
              ),
              title: Text(otherName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(jobCategory, style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                  Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.grey)),
                ],
              ),
              trailing: Text(timeStr, style: const TextStyle(fontSize: 12, color: AppColors.grey)),
            );
          },
        );
      },
    );
  }
}
