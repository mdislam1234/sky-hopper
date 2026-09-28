import 'package:flutter/material.dart';

import '../../core/widgets/sky_page.dart';
import 'models/progression_snapshot.dart';

class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({
    required this.load,
    required this.onPlay,
    required this.onBack,
    super.key,
  });

  final Future<ProgressionSnapshot> Function() load;
  final void Function(ProgressionSnapshot snapshot, bool ranked) onPlay;
  final VoidCallback onBack;

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  ProgressionSnapshot? snapshot;
  bool loading = true;
  String? error;

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
      final loaded = await widget.load().timeout(const Duration(seconds: 15));
      if (mounted) setState(() => snapshot = loaded);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Daily Challenge could not be loaded. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _date(DateTime value) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[value.month - 1]} ${value.day}, ${value.year} UTC';
  }

  @override
  Widget build(BuildContext context) => SkyPage(
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
                'DAILY CHALLENGE',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Refresh Daily Challenge',
              onPressed: loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (error != null) ...[
          Text(error!, textAlign: TextAlign.center),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ] else if (snapshot case final data?) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.public_rounded, size: 42),
                  const SizedBox(height: 8),
                  Text(_date(data.challengeDate)),
                  const SizedBox(height: 8),
                  const Text(
                    'Everyone gets the same platforms, hazards and major coin route today.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _Stat(
            'ATTEMPTS',
            '${data.attemptsRemaining} / ${data.attemptLimit} remaining',
          ),
          _Stat('YOUR DAILY BEST', '${data.dailyBest}'),
          _Stat('TOP DAILY SCORE', '${data.topDailyScore}'),
          _Stat(
            'PLAY STREAK',
            '${data.currentStreak} day${data.currentStreak == 1 ? '' : 's'}',
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => widget.onPlay(data, data.rankedAttemptAvailable),
            icon: Icon(
              data.rankedAttemptAvailable
                  ? Icons.play_arrow_rounded
                  : Icons.sports_esports_outlined,
            ),
            label: Text(
              data.rankedAttemptAvailable ? 'PLAY DAILY' : 'PRACTICE DAILY',
            ),
          ),
          if (!data.rankedAttemptAvailable) ...[
            const SizedBox(height: 8),
            const Text(
              'Ranked attempts are exhausted. Practice results are not saved or ranked.',
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    ),
  );
}
