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
        elevation: primary ? 7 : 2,
        shadowColor: primary
            ? AppColors.orange.withValues(alpha: 0.55)
            : AppColors.deepBlue.withValues(alpha: 0.16),
        minimumSize: Size(0, primary ? 80 : 60),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(primary ? 30 : 24),
        ),
        textStyle: TextStyle(
          fontSize: primary ? 30 : 20,
          fontWeight: FontWeight.w900,
          letterSpacing: primary ? 1 : 0,
        ),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Icon(icon, size: primary ? 40 : 24)),
          SizedBox(width: primary ? 20 : 12),
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}
