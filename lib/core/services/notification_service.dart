import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> init() async {
    // 1. Request permissions
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Initialize local notifications for foreground messages
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _notificationsPlugin.initialize(settings: initializationSettings);

    // 3. Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        showNotification(
          id: message.hashCode,
          title: message.notification!.title ?? 'KamKaj',
          body: message.notification!.body ?? '',
        );
      }
    });

    // 4. Handle notification clicks (app in background/terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // You can navigate to a specific screen here based on message.data
    });

    // Check if app was opened from a terminated state via notification
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      // Handle initial message
    }

    // 5. Update FCM token in Firestore
    _updateToken();

    // 6. Listen for Firestore notifications (Foreground fallback)
    _listenForFirestoreNotifications();
  }

  void _listenForFirestoreNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('is_read', isEqualTo: false)
        .orderBy('created_at', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          showNotification(
            id: change.doc.id.hashCode,
            title: data['title'] ?? 'KamKaj',
            body: data['body'] ?? '',
          );
          // Mark as read so it doesn't trigger again on next app start
          change.doc.reference.update({'is_read': true});
        }
      }
    });
  }

  Future<void> _updateToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await _fcm.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'fcm_token': token,
          'last_token_update': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'kamkaj_channel',
      'KamKaj Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
    );
  }

  // Helper to send a notification (saves to Firestore for history and trigger)
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).collection('notifications').add({
      'title': title,
      'body': body,
      'data': data,
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
    });
  }
}
