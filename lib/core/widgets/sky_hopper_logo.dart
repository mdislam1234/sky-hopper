import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SkyHopperLogo extends StatelessWidget {
  const SkyHopperLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.cloud,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepBlue.withValues(alpha: 0.12),
                  offset: const Offset(0, 8),
                  blurRadius: 24,
                ),
              ],
            ),
            child: const Icon(
              Icons.keyboard_double_arrow_up_rounded,
              size: 64,
              color: AppColors.deepBlue,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'SKY HOPPER',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: AppColors.deepBlue,
          ),
        ),
      ],
    );
  }
}
