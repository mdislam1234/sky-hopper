import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SkyBackground extends StatelessWidget {
  const SkyBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.sky, AppColors.paleSky],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(top: 32, left: -36, child: _Cloud(size: 180)),
          const Positioned(top: 100, right: -28, child: _Cloud(size: 140)),
          const Positioned(bottom: -48, right: 24, child: _Cloud(size: 220)),
          child,
        ],
      ),
    );
  }
}

class _Cloud extends StatelessWidget {
  const _Cloud({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Icon(Icons.cloud_rounded, size: size, color: AppColors.cloud),
    );
  }
}
