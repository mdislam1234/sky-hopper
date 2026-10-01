import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class HomeActionCard extends StatelessWidget {
  const HomeActionCard({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cloud.withValues(alpha: 0.9),
      elevation: 1,
      shadowColor: AppColors.deepBlue.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.34),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 23, color: AppColors.deepBlue),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.deepBlue,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
