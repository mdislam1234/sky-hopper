import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Presentation only. Values can later come from the authenticated profile.
class PlayerSummaryCard extends StatelessWidget {
  const PlayerSummaryCard({
    this.playerName = 'Guest Player',
    this.coins = 0,
    super.key,
  });
  final String playerName;
  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cloud.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cloud),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 24,
        runSpacing: 12,
        children: [
          Text(playerName, style: Theme.of(context).textTheme.titleMedium),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ExcludeSemantics(
                child: Icon(
                  Icons.monetization_on_rounded,
                  color: AppColors.deepBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Coins: $coins',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
