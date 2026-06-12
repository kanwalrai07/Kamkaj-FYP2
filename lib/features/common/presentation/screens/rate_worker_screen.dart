import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/services/service_providers.dart';

class RateWorkerScreen extends ConsumerStatefulWidget {
  final String workerId;
  const RateWorkerScreen({super.key, required this.workerId});

  @override
  ConsumerState<RateWorkerScreen> createState() => _RateWorkerScreenState();
}

class _RateWorkerScreenState extends ConsumerState<RateWorkerScreen> {
  double _rating = 0;
  final _commentController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a rating')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final currentUser = ref.read(authServiceProvider).currentUser;
      await ref.read(jobServiceProvider).submitReview(
            workerId: widget.workerId,
            clientId: currentUser?.uid ?? '',
            rating: _rating,
            comment: _commentController.text.trim(),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback!')),
        );
        context.go('/client-home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Worker', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: ref.read(authServiceProvider).getUserProfile(widget.workerId),
        builder: (context, snapshot) {
          final workerData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final workerName = workerData['full_name'] ?? 'Worker';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.person, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(workerName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Text('How was your experience?', style: TextStyle(color: AppColors.grey)),
                const SizedBox(height: 32),
                RatingBar.builder(
                  initialRating: 0,
                  minRating: 1,
                  direction: Axis.horizontal,
                  allowHalfRating: true,
                  itemCount: 5,
                  itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                  itemBuilder: (context, _) => const Icon(
                    Icons.star,
                    color: Colors.amber,
                  ),
                  onRatingUpdate: (rating) {
                    setState(() => _rating = rating);
                  },
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _commentController,
                  maxLines: 4,
                  decoration: const InputDecoration(hintText: 'Leave a comment...'),
                ),
                const SizedBox(height: 48),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _submit,
                        child: const Text('SUBMIT REVIEW'),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}
