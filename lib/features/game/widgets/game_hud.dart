import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class GameHud extends StatelessWidget {
  const GameHud({
    required this.score,
    required this.onPause,
    this.coins = 0,
    super.key,
  });
  final int score;
  final int coins;
  final VoidCallback onPause;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.cloud,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SCORE: $score',
                    style: const TextStyle(
                      color: AppColors.deepBlue,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'COINS: $coins',
                    style: const TextStyle(color: AppColors.deepBlue),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: onPause,
          tooltip: 'Pause game',
          icon: const Icon(Icons.pause_rounded),
        ),
      ],
    ),
  );
}
