import 'package:flutter/material.dart';

import '../models/progression_snapshot.dart';

class ProgressionGoalCard extends StatelessWidget {
  const ProgressionGoalCard({
    required this.goal,
    required this.busy,
    required this.onClaim,
    super.key,
  });

  final ProgressionGoal goal;
  final bool busy;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Badge(icon: goal.icon, completed: goal.completed),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(goal.description),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '+${goal.reward}',
                semanticsLabel: '${goal.reward} coin reward',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const Icon(Icons.monetization_on_rounded, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: goal.completion),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  goal.claimed
                      ? 'CLAIMED'
                      : goal.completed
                      ? 'COMPLETE'
                      : '${goal.progress.clamp(0, goal.target)} / ${goal.target}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (goal.canClaim)
                FilledButton.tonal(
                  onPressed: busy ? null : onClaim,
                  child: const Text('CLAIM'),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({this.icon, required this.completed});
  final String? icon;
  final bool completed;

  IconData get data => switch (icon) {
    'flight' => Icons.flight_takeoff_rounded,
    'cloud' => Icons.cloud_outlined,
    'storm' => Icons.thunderstorm_outlined,
    'night' => Icons.nightlight_round,
    'stars' => Icons.auto_awesome_rounded,
    'perfect' => Icons.adjust_rounded,
    'danger' => Icons.bolt_rounded,
    'coin' => Icons.monetization_on_outlined,
    'trophy' => Icons.emoji_events_outlined,
    'calendar' => Icons.calendar_today_outlined,
    'streak' => Icons.local_fire_department_outlined,
    _ => Icons.flag_outlined,
  };

  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: completed
          ? const Color(0xFFFFD45A)
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: BoxShape.circle,
    ),
    child: Icon(data, semanticLabel: completed ? 'Completed' : 'Locked'),
  );
}
