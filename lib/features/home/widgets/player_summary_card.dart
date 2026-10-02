import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Presentation only. Values can later come from the authenticated profile.
class PlayerSummaryCard extends StatelessWidget {
  const PlayerSummaryCard({
    this.playerName = 'Guest Player',
    this.coins = 0,
    this.isGuest = false,
    this.avatarUrl,
    this.onPressed,
    super.key,
  });
  final String playerName;
  final int coins;
  final bool isGuest;
  final String? avatarUrl;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cloud.withValues(alpha: 0.94),
      elevation: 4,
      shadowColor: AppColors.deepBlue.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              ExcludeSemantics(
                child: _PlayerAvatar(
                  avatarUrl: isGuest ? null : avatarUrl,
                  isGuest: isGuest,
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
              const SizedBox(width: 10),
              Container(
                width: 1,
                height: 34,
                color: AppColors.deepBlue.withValues(alpha: 0.12),
              ),
              const SizedBox(width: 10),
              ExcludeSemantics(
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.orange, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.orange.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: AppColors.cloud,
                    size: 22,
                  ),
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

class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar({required this.avatarUrl, required this.isGuest});

  final String? avatarUrl;
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.sky, AppColors.royalBlue],
        ),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isGuest ? Icons.person_outline_rounded : Icons.person_rounded,
        color: AppColors.cloud,
        size: 28,
      ),
    );
    final url = avatarUrl?.trim();
    return SizedBox.square(
      dimension: 46,
      child: ClipOval(
        child: url == null || url.isEmpty
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}
