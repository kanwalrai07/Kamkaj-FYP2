import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/services/service_providers.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data?.docs ?? [];

          if (notifications.isEmpty) {
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
                    child: Icon(Icons.notifications_none_outlined, size: 64, color: AppColors.primary.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No notifications yet',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We will notify you about your jobs and messages',
                    style: TextStyle(color: AppColors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final data = doc.data() as Map<String, dynamic>;
              final createdAt = (data['created_at'] as Timestamp?)?.toDate();
              final timeStr = createdAt != null ? DateFormat('hh:mm a, dd MMM').format(createdAt) : 'Recently';
              final isRead = data['is_read'] ?? false;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isRead ? Colors.white : AppColors.primary.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isRead ? AppColors.lightGrey.withValues(alpha: 0.5) : AppColors.primary.withValues(alpha: 0.1),
                  ),
                ),
                child: ListTile(
                  onTap: () async {
                    await doc.reference.update({'is_read': true});
                    // Handle navigation based on data if needed
                  },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isRead ? AppColors.grey : AppColors.primary).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getIcon(data['title'] ?? ''),
                      color: isRead ? AppColors.grey : AppColors.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    data['title'] ?? 'Notification',
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        data['body'] ?? '',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        timeStr,
                        style: const TextStyle(color: AppColors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                  trailing: !isRead ? Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ) : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('bid')) return Icons.gavel;
    if (t.contains('assign')) return Icons.person_add;
    if (t.contains('progress')) return Icons.timer;
    if (t.contains('complete')) return Icons.check_circle;
    if (t.contains('message')) return Icons.message;
    if (t.contains('review')) return Icons.star;
    return Icons.notifications;
  }
}
