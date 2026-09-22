import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/widgets/sky_hopper_logo.dart';
import '../../core/widgets/sky_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({required this.onComplete, super.key});
  final VoidCallback onComplete;
  static const duration = Duration(seconds: 2);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Timer _timer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.94, end: 1).animate(_fade);
    _timer = Timer(SplashScreen.duration, _openHome);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
  }

  void _openHome() {
    if (!mounted || _navigated) return;
    _navigated = true;
    widget.onComplete();
  }

  @override
  void dispose() {
    _timer.cancel();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SkyPage(
      child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SkyHopperLogo(),
              const SizedBox(height: 20),
              Text(
                'Jump beyond the clouds',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
