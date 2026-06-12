import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../widgets/active_job_banner.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/service_providers.dart';
import '../screens/worker_dashboard_screen.dart';
import '../screens/worker_profile_screen.dart';
import '../screens/earnings_screen.dart';
import '../../../common/presentation/screens/chat_list_screen.dart';

class WorkerMainScreen extends ConsumerStatefulWidget {
  const WorkerMainScreen({super.key});

  @override
  ConsumerState<WorkerMainScreen> createState() => _WorkerMainScreenState();
}

class _WorkerMainScreenState extends ConsumerState<WorkerMainScreen> {
  int _currentIndex = 0;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<QuerySnapshot>? _jobSubscription;

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
    _listenForAssignments();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _jobSubscription?.cancel();
    super.dispose();
  }

  String? _lastNavigatedJobId;

  void _listenForAssignments() {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    _jobSubscription = FirebaseFirestore.instance
        .collection('jobs')
        .where('worker_id', isEqualTo: user.uid)
        .where('status', isEqualTo: 'assigned')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty && mounted) {
        final jobId = snapshot.docs.first.id;
        if (_lastNavigatedJobId != jobId) {
          _lastNavigatedJobId = jobId;
          // Auto-navigate to tracking screen when a job is assigned
          context.push(AppRouter.workerTracking, extra: jobId);
        }
      } else if (snapshot.docs.isEmpty) {
        _lastNavigatedJobId = null;
      }
    });
  }

  void _startLocationTracking() async {
    // 1. Check permissions
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    // 2. Start tracking if there is an active job
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) async {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) return;

      // Find if worker has an active job assigned
      final activeJobs = await FirebaseFirestore.instance
          .collection('jobs')
          .where('worker_id', isEqualTo: user.uid)
          .where('status', isEqualTo: 'assigned')
          .limit(1)
          .get();

      if (activeJobs.docs.isNotEmpty) {
        final jobId = activeJobs.docs.first.id;
        // Push to RTDB for <1.5s latency
        await ref.read(jobServiceProvider).updateWorkerLocation(
              jobId,
              user.uid,
              position.latitude,
              position.longitude,
            );
      }
    });
  }

  final List<Widget> _screens = [
    const WorkerDashboardScreen(),
    const ChatListScreen(),
    const EarningsScreen(),
    const WorkerProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Optionally show a dialog here or just do nothing to prevent closing
      },
      child: Scaffold(
        appBar: _currentIndex == 0 ? AppBar(
          title: const Text('Worker Dashboard', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_none, color: Colors.black),
              onPressed: () => context.push(AppRouter.notifications),
            ),
          ],
        ) : null,
        body: Column(
          children: [
            const SafeArea(bottom: false, child: ActiveJobBanner(role: 'worker')),
            Expanded(child: _screens[_currentIndex]),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.grey,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
            BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Earnings'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
