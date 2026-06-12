import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

class ProfileField extends StatelessWidget {
  final String label;
  final String value;
  final bool isEditable;
  final VoidCallback? onEdit;

  const ProfileField({
    super.key,
    required this.label,
    required this.value,
    this.isEditable = false,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.grey)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isEditable ? AppColors.lightGrey : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isEditable ? null : Border.all(color: AppColors.lightGrey.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
              if (isEditable)
                IconButton(
                  icon: const Icon(Icons.edit, size: 18, color: AppColors.primary),
                  onPressed: onEdit,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
