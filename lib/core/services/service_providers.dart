import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/job_service.dart';
import '../services/chat_service.dart';
import '../services/admin_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final jobServiceProvider = Provider<JobService>((ref) {
  return JobService();
});

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService();
});
