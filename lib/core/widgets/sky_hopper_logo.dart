import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SkyHopperLogo extends StatelessWidget {
  const SkyHopperLogo({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Container(
            width: compact ? 56 : 88,
            height: compact ? 56 : 88,
            decoration: BoxDecoration(
              color: AppColors.cloud,
              borderRadius: BorderRadius.circular(compact ? 20 : 30),
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepBlue.withValues(alpha: 0.12),
                  offset: const Offset(0, 8),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Icon(
              Icons.keyboard_double_arrow_up_rounded,
              size: compact ? 42 : 64,
              color: AppColors.deepBlue,
            ),
          ),
        ),
        SizedBox(height: compact ? 10 : 20),
        Text(
          'SKY HOPPER',
          textAlign: TextAlign.center,
          style:
              (compact
                      ? Theme.of(context).textTheme.headlineMedium
                      : Theme.of(context).textTheme.displaySmall)
                  ?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: AppColors.deepBlue,
                  ),
        ),
      ],
    );
  }
}
