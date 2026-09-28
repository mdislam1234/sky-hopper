import 'package:flutter/material.dart';

import '../../core/widgets/sky_page.dart';
import 'models/progression_snapshot.dart';
import 'widgets/progression_goal_card.dart';

class ProgressionGoalsScreen extends StatefulWidget {
  const ProgressionGoalsScreen({
    required this.kind,
    required this.load,
    required this.claim,
    required this.onBack,
    this.onBalanceChanged,
    super.key,
  });

  final RewardKind kind;
  final Future<ProgressionSnapshot> Function() load;
  final Future<RewardClaim> Function(RewardKind kind, String id) claim;
  final VoidCallback onBack;
  final Future<void> Function()? onBalanceChanged;

  @override
  State<ProgressionGoalsScreen> createState() => _ProgressionGoalsScreenState();
}

class _ProgressionGoalsScreenState extends State<ProgressionGoalsScreen> {
  ProgressionSnapshot? snapshot;
  bool loading = true;
  String? busyId;
  String? error;

  List<ProgressionGoal> get goals => widget.kind == RewardKind.mission
      ? snapshot?.missions ?? const []
      : snapshot?.achievements ?? const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await widget.load().timeout(const Duration(seconds: 15));
      if (mounted) setState(() => snapshot = value);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Progress could not be loaded. Try again.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _claim(ProgressionGoal goal) async {
    if (busyId != null || !goal.canClaim) return;
    setState(() {
      busyId = goal.id;
      error = null;
    });
    try {
      final result = await widget
          .claim(widget.kind, goal.id)
          .timeout(const Duration(seconds: 15));
      await widget.onBalanceChanged?.call();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                result.alreadyClaimed
                    ? 'Reward was already claimed.'
                    : '+${result.rewardGranted} coins claimed!',
              ),
            ),
          );
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Reward could not be confirmed. Try again.');
      }
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.kind == RewardKind.mission
        ? 'DAILY MISSIONS'
        : 'ACHIEVEMENTS';
    return SkyPage(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Home',
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Refresh $title',
                onPressed: loading ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (widget.kind == RewardKind.mission && snapshot != null)
            Text(
              'Resets at 00:00 UTC · ${snapshot!.currentStreak} day streak',
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 16),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (error != null && goals.isEmpty) ...[
            Text(error!, textAlign: TextAlign.center),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ] else ...[
            if (error != null) Text(error!, textAlign: TextAlign.center),
            for (final goal in goals)
              ProgressionGoalCard(
                key: ValueKey('${widget.kind.name}-${goal.id}'),
                goal: goal,
                busy: busyId != null,
                onClaim: () => _claim(goal),
              ),
          ],
        ],
      ),
    );
  }
}
