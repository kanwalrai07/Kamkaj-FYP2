import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/constants/colors.dart';
import '../screens/client_home_screen.dart';
import '../screens/client_profile_screen.dart';
import '../../../common/presentation/screens/chat_list_screen.dart';
import '../../../common/presentation/screens/job_history_screen.dart';
import '../../../../core/services/service_providers.dart';

class ClientMainScreen extends ConsumerStatefulWidget {
  const ClientMainScreen({super.key});

  @override
  ConsumerState<ClientMainScreen> createState() => _ClientMainScreenState();
}

class _ClientMainScreenState extends ConsumerState<ClientMainScreen> {
  int _currentIndex = 0;
  StreamSubscription<QuerySnapshot>? _jobSubscription;
  String? _lastNavigatedJobId;

  @override
  void initState() {
    super.initState();
    _listenForAssignments();
  }

  @override
  void dispose() {
    _jobSubscription?.cancel();
    super.dispose();
  }

  void _listenForAssignments() {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    _jobSubscription = FirebaseFirestore.instance
        .collection('jobs')
        .where('client_id', isEqualTo: user.uid)
        .where('status', isEqualTo: 'assigned')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty && mounted) {
        final jobId = snapshot.docs.first.id;
        if (_lastNavigatedJobId != jobId) {
          _lastNavigatedJobId = jobId;
          // Auto-navigate to tracking screen when a job is assigned
          context.push(AppRouter.liveTracking, extra: jobId);
        }
      } else if (snapshot.docs.isEmpty) {
        _lastNavigatedJobId = null;
      }
    });
  }

  final List<Widget> _screens = [
    const ClientHomeScreen(),
    const ChatListScreen(),
    const JobHistoryScreen(),
    const ClientProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: _currentIndex == 0 ? AppBar(
          title: const Text(
            'KamKaj',
            style: TextStyle(
              color: AppColors.secondary,
              fontWeight: FontWeight.w900,
              fontSize: 24,
              letterSpacing: -0.5,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.notifications_outlined, color: AppColors.primary),
                onPressed: () => GoRouter.of(context).push('/notifications'),
              ),
            ),
          ],
        ) : null,
        body: Column(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _screens[_currentIndex],
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.grey.withValues(alpha: 0.6),
            selectedFontSize: 12,
            unselectedFontSize: 12,
            elevation: 0,
            items: [
              _buildNavItem(Icons.home_rounded, Icons.home_outlined, 'Home', 0),
              _buildNavItem(Icons.chat_bubble_rounded, Icons.chat_bubble_outline_rounded, 'Messages', 1),
              _buildNavItem(Icons.history_rounded, Icons.history_outlined, 'History', 2),
              _buildNavItem(Icons.person_rounded, Icons.person_outline_rounded, 'Profile', 3),
            ],
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(IconData selectedIcon, IconData unselectedIcon, String label, int index) {
    final isSelected = _currentIndex == index;
    return BottomNavigationBarItem(
      icon: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(isSelected ? selectedIcon : unselectedIcon),
      ),
      label: label,
    );
  }
}
