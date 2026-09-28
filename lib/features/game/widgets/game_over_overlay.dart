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
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text('Previous best: $previousBest'),
                ],
                if (!paused && causeMessage != null) ...[
                  Text(
                    causeMessage!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                SizedBox(height: causeMessage == null ? 12 : 4),
                Text(
                  '${paused ? 'Score' : 'Final Score'}: $score',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: causeMessage == null ? 24 : 16),
                Text('${paused ? 'Coins' : 'Coins Collected'}: $coins'),
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
                    TextButton(
                      onPressed: onRetry,
                      child: const Text('RETRY SAVE'),
                    ),
                  if (rewardStatus case final status?) ...[
                    const SizedBox(height: 8),
                    Semantics(
                      liveRegion: true,
                      child: Text(status, textAlign: TextAlign.center),
                    ),
                  ],
                  if (rewardActionLabel case final label?) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: rewardBusy || !rewardActionEnabled
                          ? null
                          : onReward,
                      icon: rewardBusy || rewardLoading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.ondemand_video_rounded),
                      label: Text(label),
                    ),
                    if (onRewardRetry != null)
                      TextButton(
                        onPressed: rewardBusy ? null : onRewardRetry,
                        child: const Text('RETRY VIDEO'),
                      ),
                  ],
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onContinue,
                  icon: Icon(paused ? Icons.play_arrow : Icons.replay),
                  label: Text(paused ? 'RESUME' : 'RESTART'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onHome,
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('HOME'),
                ),
                if (!paused &&
                    (savePhase == SavePhase.saving ||
                        savePhase == SavePhase.failed))
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
            ),
          ),
        ),
      ),
    ),
  );
}
