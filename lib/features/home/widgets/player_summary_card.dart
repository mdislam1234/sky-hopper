import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Presentation only. Values can later come from the authenticated profile.
class PlayerSummaryCard extends StatelessWidget {
  const PlayerSummaryCard({
    this.playerName = 'Guest Player',
    this.coins = 0,
    this.isGuest = false,
    this.onPressed,
    super.key,
  });
  final String playerName;
  final int coins;
  final bool isGuest;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cloud.withValues(alpha: 0.86),
      elevation: 1,
      shadowColor: AppColors.deepBlue.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.paleSky,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    isGuest
                        ? Icons.person_outline_rounded
                        : Icons.person_rounded,
                    color: AppColors.deepBlue,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  playerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.deepBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ExcludeSemantics(
                child: Icon(
                  Icons.monetization_on_rounded,
                  color: AppColors.deepBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Coins: $coins',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.deepBlue,
                    fontWeight: FontWeight.w800,
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
