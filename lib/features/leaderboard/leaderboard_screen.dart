import 'package:flutter/material.dart';

import '../../core/widgets/sky_page.dart';
import 'data/leaderboard_repository.dart';
import 'models/leaderboard_entry.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    required this.load,
    required this.onBack,
    super.key,
  });
  final LoadLeaderboard load;
  final VoidCallback onBack;
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _loading = true;
  String? _error;
  List<LeaderboardEntry> _entries = const [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.load().timeout(const Duration(seconds: 15));
      if (mounted) setState(() => _entries = rows);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Leaderboard could not be loaded. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                'LEADERBOARD',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Refresh leaderboard',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_loading)
          const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Loading leaderboard',
            ),
          )
        else if (_error != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(_error!, textAlign: TextAlign.center),
          ),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ] else if (_entries.isEmpty)
          const Text(
            'No scores yet. Be the first to climb!',
            textAlign: TextAlign.center,
          )
        else
          for (final entry in _entries)
            Card(
              key: ValueKey('rank-${entry.rank}'),
              color: entry.isCurrentUser ? const Color(0xFFFFE69A) : null,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Text(
                      '#${entry.rank}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(width: 12),
                    ClipOval(
                      child: entry.avatarUrl == null
                          ? const _AvatarFallback()
                          : Image.network(
                              entry.avatarUrl!,
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              errorBuilder: (_, error, stack) =>
                                  const _AvatarFallback(),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (entry.isCurrentUser)
                            const Text(
                              'YOU',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          Text(
                            'Score ${entry.bestScore} · Height ${entry.bestHeight}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    ),
  );
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();
  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: 36, height: 36, child: Icon(Icons.person_outline));
}
