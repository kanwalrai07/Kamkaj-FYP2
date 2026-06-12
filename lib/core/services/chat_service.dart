import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class ChatService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final NotificationService _notificationService = NotificationService();

  // Send a message via Realtime Database for sub-second latency
  Future<void> sendMessage({
    required String jobId,
    required String senderId,
    required String text,
  }) async {
    final messageRef = _database.ref('chats/$jobId/messages').push();
    await messageRef.set({
      'sender_id': senderId,
      'text': text,
      'timestamp': ServerValue.timestamp,
    });
    
    // Update last message info for the chat list
    await _database.ref('chats/$jobId/last_message').set({
      'text': text,
      'sender_id': senderId,
      'timestamp': ServerValue.timestamp,
    });

    // Notify Receiver
    final jobDoc = await FirebaseFirestore.instance.collection('jobs').doc(jobId).get();
    if (jobDoc.exists) {
      final jobData = jobDoc.data() as Map<String, dynamic>;
      final clientId = jobData['client_id'];
      final workerId = jobData['worker_id'];
      
      final receiverId = senderId == clientId ? workerId : clientId;
      
      if (receiverId != null) {
        await _notificationService.sendNotification(
          userId: receiverId,
          title: 'New Message',
          body: text.length > 50 ? '${text.substring(0, 47)}...' : text,
          data: {'job_id': jobId},
        );
      }
    }
  }

  // Stream of messages for a job
  Stream<DatabaseEvent> getMessages(String jobId) {
    return _database
        .ref('chats/$jobId/messages')
        .orderByChild('timestamp')
        .onValue;
  }
}
