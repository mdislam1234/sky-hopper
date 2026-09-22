import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'sky_page.dart';
import 'sky_hopper_logo.dart';

/// One bootstrap attempt at a time. Failures never render SDK/config payloads.
class AppStartup extends StatefulWidget {
  const AppStartup({required this.initialize, super.key});
  final Future<Widget> Function() initialize;
  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  late Future<Widget> _attempt;
  @override
  void initState() {
    super.initState();
    _attempt = Future.sync(widget.initialize);
  }

  void _retry() {
    setState(() {
      _attempt = Future.sync(widget.initialize);
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Widget>(
    future: _attempt,
    builder: (context, snapshot) {
      if (snapshot.hasData) return snapshot.data!;
      final failed = snapshot.hasError;
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Sky Hopper',
        theme: AppTheme.light,
        home: SkyPage(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SkyHopperLogo(),
              const SizedBox(height: 24),
              if (!failed)
                const CircularProgressIndicator(
                  semanticsLabel: 'Starting Sky Hopper',
                ),
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Text(
                  failed
                      ? 'Unable to start Sky Hopper. Check your connection and try again.'
                      : 'Getting ready…',
                  textAlign: TextAlign.center,
                ),
              ),
              if (failed) ...[
                const SizedBox(height: 16),
                FilledButton(onPressed: _retry, child: const Text('Retry')),
              ],
            ],
          ),
        ),
      );
    },
  );
}
