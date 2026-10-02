import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../systems/run_save_controller.dart';

class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({
    required this.score,
    required this.paused,
    required this.onContinue,
    required this.onHome,
    this.coins = 0,
    this.savePhase = SavePhase.notStarted,
    this.onRetry,
    this.causeMessage,
    this.newPersonalBest = false,
    this.previousBest = 0,
    this.rewardActionLabel,
    this.onReward,
    this.onRewardRetry,
    this.rewardActionEnabled = true,
    this.rewardLoading = false,
    this.rewardBusy = false,
    this.rewardStatus,
    super.key,
  });

  final int score;
  final int coins;
  final SavePhase savePhase;
  final VoidCallback? onRetry;
  final String? causeMessage;
  final bool newPersonalBest;
  final int previousBest;
  final String? rewardActionLabel;
  final VoidCallback? onReward;
  final VoidCallback? onRewardRetry;
  final bool rewardActionEnabled;
  final bool rewardLoading;
  final bool rewardBusy;
  final String? rewardStatus;
  final bool paused;
  final VoidCallback onContinue;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.deepBlue.withValues(alpha: 0.6),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth > 40
            ? constraints.maxWidth - 40
            : constraints.maxWidth;
        final cardWidth = availableWidth.clamp(0.0, 360.0).toDouble();
        final contentPadding = cardWidth < 280 ? 16.0 : 24.0;
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: cardWidth,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(contentPadding),
                  child: _content(context),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _content(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        paused ? Icons.pause_circle_outline : Icons.cloud_outlined,
        size: 48,
        color: AppColors.deepBlue,
      ),
      const SizedBox(height: 12),
      Text(
        paused ? 'PAUSED' : 'GAME OVER',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      if (!paused && newPersonalBest) ...[
        const SizedBox(height: 6),
        Text(
          'NEW PERSONAL BEST',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: AppColors.gold, fontWeight: FontWeight.w900),
        ),
        Text('Previous best: $previousBest'),
      ],
      if (!paused && causeMessage != null)
        Text(
          causeMessage!,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      SizedBox(height: causeMessage == null ? 12 : 4),
      _singleLine(
        '${paused ? 'Score' : 'Final Score'}: $score',
        key: const Key('game-overlay-score'),
        style: Theme.of(context).textTheme.titleLarge,
      ),
      SizedBox(height: causeMessage == null ? 24 : 16),
      _singleLine(
        '${paused ? 'Coins' : 'Coins Collected'}: $coins',
        key: const Key('game-overlay-coins'),
      ),
      if (!paused) ...[
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(switch (savePhase) {
            SavePhase.saving => 'Saving…',
            SavePhase.saved => 'Saved',
            SavePhase.failed => 'Could not confirm save. Try again.',
            SavePhase.preview => 'Preview — saving disabled',
            SavePhase.notStarted => 'Preparing result…',
          }, textAlign: TextAlign.center),
        ),
        if (newPersonalBest && savePhase == SavePhase.failed)
          Text(
            'Run best: $score — server save not confirmed.',
            textAlign: TextAlign.center,
          ),
        if (savePhase == SavePhase.failed)
          TextButton(onPressed: onRetry, child: const Text('RETRY SAVE')),
        if (rewardStatus case final status?) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(status, textAlign: TextAlign.center),
          ),
        ],
        if (rewardActionLabel case final label?) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 52),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: rewardBusy || !rewardActionEnabled ? null : onReward,
              icon: rewardBusy || rewardLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ondemand_video_rounded),
              label: _singleLine(
                label,
                key: const Key('game-overlay-reward-label'),
              ),
            ),
          ),
          if (onRewardRetry != null)
            TextButton(
              onPressed: rewardBusy ? null : onRewardRetry,
              child: const Text('RETRY VIDEO'),
            ),
        ],
      ],
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 56),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          onPressed: onContinue,
          icon: Icon(paused ? Icons.play_arrow : Icons.replay),
          label: _singleLine(
            paused ? 'RESUME' : 'RESTART',
            key: const Key('game-overlay-primary-label'),
          ),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          onPressed: onHome,
          icon: const Icon(Icons.home_outlined),
          label: _singleLine('HOME', key: const Key('game-overlay-home-label')),
        ),
      ),
      if (!paused &&
          (savePhase == SavePhase.saving || savePhase == SavePhase.failed))
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            savePhase == SavePhase.saving
                ? 'You can leave; this save may finish in the background.'
                : 'Retry before leaving. Unsaved runs are not kept for later retry.',
            textAlign: TextAlign.center,
          ),
        ),
    ],
  );

  Widget _singleLine(String text, {Key? key, TextStyle? style}) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(
      text,
      key: key,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
      style: style,
    ),
  );
}
