import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/router/app_router.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool isClient = true;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
      },
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        const CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.primary,
                          child: Icon(Icons.handyman, size: 50, color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'KAMKAJ',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const Text(
                          'Your Work, Our Way',
                          style: TextStyle(fontSize: 14, color: AppColors.grey),
                        ),
                        const SizedBox(height: 60),
                        const Text(
                          'How would you like to join KAMKAJ?',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: _RoleButton(
                                title: 'Client',
                                isSelected: isClient,
                                onTap: () => setState(() => isClient = true),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _RoleButton(
                                title: 'Worker',
                                isSelected: !isClient,
                                onTap: () => setState(() => isClient = false),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),
                        ElevatedButton(
                          onPressed: () {
                            if (isClient) {
                              context.push(AppRouter.clientLogin);
                            } else {
                              context.push(AppRouter.workerLogin);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, Color(0xFF1E3A8A)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Container(
                              height: 56,
                              alignment: Alignment.center,
                              child: const Text(
                                'CONTINUE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Role Selection',
                          style: TextStyle(color: AppColors.grey),
                        ),
                        const SizedBox(height: 40),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Are you an Admin? ', style: TextStyle(color: AppColors.grey, fontSize: 12)),
                            GestureDetector(
                              onTap: () => context.push(AppRouter.adminLogin),
                              child: const Text('Login here', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleButton({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.lightGrey.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.15),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ] : [],
        ),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(
              title == 'Client' ? Icons.person_outline : Icons.engineering_outlined,
              size: 32,
              color: isSelected ? AppColors.primary : AppColors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.secondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
