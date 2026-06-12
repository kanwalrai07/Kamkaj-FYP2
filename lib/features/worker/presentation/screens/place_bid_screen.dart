import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/service_providers.dart';

class PlaceBidScreen extends ConsumerStatefulWidget {
  final String jobId;
  const PlaceBidScreen({super.key, required this.jobId});

  @override
  ConsumerState<PlaceBidScreen> createState() => _PlaceBidScreenState();
}

class _PlaceBidScreenState extends ConsumerState<PlaceBidScreen> {
  final _amountController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitBid() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid amount and message')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final workerId = ref.read(authServiceProvider).currentUser?.uid;
      if (workerId == null) throw Exception('Not logged in');

      await ref.read(jobServiceProvider).submitBid(
            jobId: widget.jobId,
            workerId: workerId,
            amount: amount,
            message: _messageController.text.trim(),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bid submitted successfully!')),
        );
        context.pop();
        context.pop();
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
        title: const Text('Submit Your Bid', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Enter your bid amount', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'e.g. 700',
                      prefixText: 'Rs. ',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Message to Client', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _messageController,
                    maxLines: 4,
                    decoration: const InputDecoration(hintText: 'Explain why you are the best fit...'),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _submitBid,
                    child: const Text('SUBMIT BID'),
                  ),
                ],
              ),
            ),
    );
  }
}
