import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class GameMenuButton extends StatelessWidget {
  const GameMenuButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
    super.key,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: primary ? AppColors.gold : AppColors.cloud,
        foregroundColor: AppColors.deepBlue,
        elevation: primary ? 4 : 1,
        shadowColor: AppColors.deepBlue.withValues(alpha: 0.18),
        minimumSize: Size(0, primary ? 72 : 60),
      ),
      onPressed: onPressed,
      child: Row(
        children: [
          ExcludeSemantics(child: Icon(icon, size: primary ? 30 : 24)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, textAlign: TextAlign.center)),
          const SizedBox(width: 24),
        ],
      ),
    );
  }
}
