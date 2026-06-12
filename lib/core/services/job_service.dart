import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

class JobService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final NotificationService _notificationService = NotificationService();

  // Post a new job (Firestore for structured data, RTDB for live tracking/status)
  Future<String> postJob({
    required String clientId,
    required String category,
    required String description,
    required String location,
    required double budget,
    required double lat,
    required double lng,
  }) async {
    // 1. Create job in Firestore
    final jobDoc = await _firestore.collection('jobs').add({
      'client_id': clientId,
      'category': category,
      'description': description,
      'location_name': location,
      'budget': budget,
      'status': 'pending', // pending, assigned, in_progress, completed, cancelled
      'created_at': FieldValue.serverTimestamp(),
      'lat': lat,
      'lng': lng,
    });

    // 2. Create entry in RTDB for low-latency updates (1-1.5s target)
    await _database.ref('active_jobs/${jobDoc.id}').set({
      'client_id': clientId,
      'status': 'pending',
      'lat': lat,
      'lng': lng,
      'last_updated': ServerValue.timestamp,
    });

    // 3. Notify workers in this category (In production, use Cloud Functions)
    // For now, we log it. A Cloud Function would query all workers with this category and send FCM.
    debugPrint('NOTIFICATION: New $category job posted in $location');

    return jobDoc.id;
  }

  // Stream of jobs for workers (Real-time updates)
  Stream<QuerySnapshot> getAvailableJobs() {
    // Log the available jobs fetch
    debugPrint('Fetching available jobs for worker...');
    return _firestore
        .collection('jobs')
        .where('status', isEqualTo: 'pending')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  // Submit a bid for a job
  Future<void> submitBid({
    required String jobId,
    required String workerId,
    required double amount,
    required String message,
  }) async {
    final jobRef = _firestore.collection('jobs').doc(jobId);
    
    await _firestore.runTransaction((transaction) async {
      final jobSnap = await transaction.get(jobRef);
      if (!jobSnap.exists) throw Exception('Job does not exist');
      
      final jobData = jobSnap.data() as Map<String, dynamic>;
      if (jobData['status'] != 'pending') {
        throw Exception('This job is no longer accepting bids');
      }

      // 1. Add bid to sub-collection
      final bidRef = jobRef.collection('bids').doc(workerId);
      transaction.set(bidRef, {
        'worker_id': workerId,
        'amount': amount,
        'message': message,
        'status': 'pending', // pending, accepted, rejected
        'created_at': FieldValue.serverTimestamp(),
      });

      // 2. Add workerId to bidder_ids array in job document for easy querying
      transaction.update(jobRef, {
        'bidder_ids': FieldValue.arrayUnion([workerId]),
      });
    });

    // Notify Client
    final jobDoc = await jobRef.get();
    if (jobDoc.exists) {
      final clientId = (jobDoc.data() as Map<String, dynamic>)['client_id'];
      final category = (jobDoc.data() as Map<String, dynamic>)['category'];
      await _notificationService.sendNotification(
        userId: clientId,
        title: 'New Bid Received',
        body: 'A worker has placed a bid of Rs. $amount on your $category job.',
        data: {'job_id': jobId},
      );
    }
  }

  // Reject a bid
  Future<void> rejectBid(String jobId, String workerId) async {
    await _firestore
        .collection('jobs')
        .doc(jobId)
        .collection('bids')
        .doc(workerId)
        .update({'status': 'rejected'});
  }

  // Stream of jobs a worker has bid on
  Stream<QuerySnapshot> getBiddedJobs(String workerId) {
    return _firestore
        .collection('jobs')
        .where('bidder_ids', arrayContains: workerId)
        .where('status', isEqualTo: 'pending')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  // Stream of bids for a specific job
  Stream<QuerySnapshot> getJobBids(String jobId) {
    return _firestore
        .collection('jobs')
        .doc(jobId)
        .collection('bids')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  // Assign a worker to a job
  Future<void> assignWorker(String jobId, String workerId, {double? price}) async {
    final jobDoc = await _firestore.collection('jobs').doc(jobId).get();
    if (!jobDoc.exists) return;
    
    final jobData = jobDoc.data() as Map<String, dynamic>;
    final category = jobData['category'] ?? 'Job';
    final clientId = jobData['client_id'];

    final Map<String, dynamic> updateData = {
      'worker_id': workerId,
      'status': 'assigned',
      'assigned_at': FieldValue.serverTimestamp(),
    };

    if (price != null) {
      updateData['final_price'] = price;
    } else {
      // If no price provided (e.g. Accept Now), use the job's budget
      updateData['final_price'] = jobData['budget'];
    }

    await _firestore.collection('jobs').doc(jobId).update(updateData);

    await _database.ref('active_jobs/$jobId').update({
      'worker_id': workerId,
      'status': 'assigned',
    });

    // Mark the bid as accepted and others as rejected
    final bidsRef = _firestore.collection('jobs').doc(jobId).collection('bids');
    final bidsSnap = await bidsRef.get();
    for (var doc in bidsSnap.docs) {
      if (doc.id == workerId) {
        await doc.reference.update({'status': 'accepted'});
      } else {
        await doc.reference.update({'status': 'rejected'});
      }
    }

    // Notify Worker
    await _notificationService.sendNotification(
      userId: workerId,
      title: 'Job Assigned!',
      body: 'You have been assigned to the $category job. Tap to start tracking.',
      data: {'job_id': jobId},
    );

    // Notify Client
    if (clientId != null) {
      await _notificationService.sendNotification(
        userId: clientId,
        title: 'Worker Assigned',
        body: 'A worker has been assigned to your $category job. Tap to track their location.',
        data: {'job_id': jobId},
      );
    }
  }

  // Update job status (En Route, Arrived, Working)
  Future<void> updateJobStatus(String jobId, String status) async {
    // status: en_route, arrived, working
    await _firestore.collection('jobs').doc(jobId).update({
      'status': status,
      'status_updated_at': FieldValue.serverTimestamp(),
    });

    await _database.ref('active_jobs/$jobId').update({
      'status': status,
    });
  }

  // Mark job as completed
  Future<void> completeJob(String jobId) async {
    final jobRef = _firestore.collection('jobs').doc(jobId);
    String? clientId;
    String? category;
    
    await _firestore.runTransaction((transaction) async {
      final jobSnap = await transaction.get(jobRef);
      if (!jobSnap.exists) return;

      final jobData = jobSnap.data() as Map<String, dynamic>;
      final workerId = jobData['worker_id'];
      clientId = jobData['client_id'];
      category = jobData['category'];
      final amount = (jobData['final_price'] ?? jobData['budget'] ?? 0.0).toDouble();

      if (workerId == null) return;

      // 1. Update job status
      transaction.update(jobRef, {
        'status': 'completed',
        'completed_at': FieldValue.serverTimestamp(),
      });

      // 2. Update worker earnings
      final workerRef = _firestore.collection('users').doc(workerId);
      transaction.update(workerRef, {
        'total_earnings': FieldValue.increment(amount),
      });

      // 3. Add to worker's transactions/earnings history
      final transactionRef = workerRef.collection('transactions').doc();
      transaction.set(transactionRef, {
        'job_id': jobId,
        'category': jobData['category'],
        'amount': amount,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'credit',
      });
    });

    await _database.ref('active_jobs/$jobId').update({
      'status': 'completed',
    });

    // Notify Client to rate worker
    if (clientId != null) {
      await _notificationService.sendNotification(
        userId: clientId!,
        title: 'Job Completed',
        body: 'The $category job is finished. Please leave a review for your worker.',
        data: {'job_id': jobId},
      );
    }
  }

  // Cancel a job
  Future<void> cancelJob(String jobId, String reason) async {
    final jobDoc = await _firestore.collection('jobs').doc(jobId).get();
    if (!jobDoc.exists) return;

    final jobData = jobDoc.data() as Map<String, dynamic>;
    final clientId = jobData['client_id'];
    final workerId = jobData['worker_id'];
    final category = jobData['category'] ?? 'Job';

    // 1. Update Firestore status
    await _firestore.collection('jobs').doc(jobId).update({
      'status': 'cancelled',
      'cancelled_at': FieldValue.serverTimestamp(),
      'cancel_reason': reason,
    });

    // 2. Update RTDB status
    await _database.ref('active_jobs/$jobId').update({
      'status': 'cancelled',
    });

    // 3. Notify both about the cancellation
    
    if (clientId != null) {
      await _notificationService.sendNotification(
        userId: clientId,
        title: 'Job Cancelled',
        body: 'The $category job has been cancelled.',
        data: {'job_id': jobId},
      );
    }
    if (workerId != null) {
      await _notificationService.sendNotification(
        userId: workerId,
        title: 'Job Cancelled',
        body: 'The $category job has been cancelled.',
        data: {'job_id': jobId},
      );
    }
  }

  // Get single job details
  Future<DocumentSnapshot> getJobDetails(String jobId) {
    return _firestore.collection('jobs').doc(jobId).get();
  }

  // Update worker location in RTDB for live tracking
  Future<void> updateWorkerLocation(String jobId, String workerId, double lat, double lng) async {
    await _database.ref('active_jobs/$jobId/worker_location').set({
      'worker_id': workerId,
      'lat': lat,
      'lng': lng,
      'last_updated': ServerValue.timestamp,
    });
  }

  // Get active job for a client
  Stream<QuerySnapshot> getClientActiveJobs(String clientId) {
    return _firestore
        .collection('jobs')
        .where('client_id', isEqualTo: clientId)
        .where('status', whereIn: ['pending', 'assigned', 'in_progress'])
        .snapshots();
  }

  // Submit rating for worker and update average (Ustaad Score component)
  Future<void> submitReview({
    required String workerId,
    required String clientId,
    required double rating,
    required String comment,
  }) async {
    final workerRef = _firestore.collection('users').doc(workerId);
    
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(workerRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final currentRating = (data['rating'] ?? 5.0).toDouble();
      final currentCount = (data['review_count'] ?? 0) as int;
      final completedJobs = (data['completed_jobs_count'] ?? 0) as int;

      final newCount = currentCount + 1;
      final newRating = ((currentRating * currentCount) + rating) / newCount;
      
      // Calculate Ustaad Score
      final ustaadScore = calculateUstaad(newRating, completedJobs + 1);

      transaction.update(workerRef, {
        'rating': newRating,
        'review_count': newCount,
        'ustaad_score': ustaadScore,
        'completed_jobs_count': FieldValue.increment(1),
      });

      // Save the review in a sub-collection for history
      final reviewRef = workerRef.collection('reviews').doc();
      transaction.set(reviewRef, {
        'client_id': clientId,
        'rating': rating,
        'comment': comment,
        'reviewer_role': 'client',
        'created_at': FieldValue.serverTimestamp(),
      });
    });

    // Notify Worker
    await _notificationService.sendNotification(
      userId: workerId,
      title: 'New Review Received',
      body: 'A client has left you a $rating star review!',
    );
  }

  // Submit rating for client (Two-way rating)
  Future<void> submitClientReview({
    required String workerId,
    required String clientId,
    required double rating,
    required String comment,
  }) async {
    final clientRef = _firestore.collection('users').doc(clientId);
    
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(clientRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final currentRating = (data['rating'] ?? 5.0).toDouble();
      final currentCount = (data['review_count'] ?? 0) as int;

      final newCount = currentCount + 1;
      final newRating = ((currentRating * currentCount) + rating) / newCount;

      transaction.update(clientRef, {
        'rating': newRating,
        'review_count': newCount,
      });

      // Save the review
      final reviewRef = clientRef.collection('reviews').doc();
      transaction.set(reviewRef, {
        'worker_id': workerId,
        'rating': rating,
        'comment': comment,
        'reviewer_role': 'worker',
        'created_at': FieldValue.serverTimestamp(),
      });
    });
  }

  // Ustaad Score Algorithm (Weighted average of ratings and experience)
  double calculateUstaad(double averageRating, int jobsCompleted) {
    // Formula: (Rating * 0.8) + (Min(Jobs/10, 1.0) * 1.0) 
    // Max score is 5.0
    double experienceBonus = (jobsCompleted / 10).clamp(0.0, 1.0);
    double score = (averageRating * 0.8) + experienceBonus;
    return double.parse(score.toStringAsFixed(2));
  }
}
