import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class HomeHero extends StatelessWidget {
  const HomeHero({required this.compact, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 104 : 132,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showMascot = constraints.maxWidth >= 270;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Semantics(
                  header: true,
                  label: 'Sky Hopper. Jump higher.',
                  child: ExcludeSemantics(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: compact ? 180 : 210,
                        child: const _HomeWordmark(),
                      ),
                    ),
                  ),
                ),
              ),
              if (showMascot) ...[
                const SizedBox(width: 6),
                ExcludeSemantics(
                  child: Container(
                    width: compact ? 82 : 100,
                    height: compact ? 82 : 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(compact ? 28 : 34),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.deepBlue.withValues(alpha: 0.2),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/branding/app_icon_adaptive_foreground.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _HomeWordmark extends StatelessWidget {
  const _HomeWordmark();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _OutlinedWord(text: 'SKY', color: AppColors.cloud, fontSize: 43),
        const _OutlinedWord(
          text: 'HOPPER',
          color: AppColors.gold,
          fontSize: 37,
        ),
        const SizedBox(height: 5),
        Text(
          '—  J U M P   H I G H E R  —',
          maxLines: 1,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.deepBlue,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _OutlinedWord extends StatelessWidget {
  const _OutlinedWord({
    required this.text,
    required this.color,
    required this.fontSize,
  });

  final String text;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: fontSize,
      height: 0.84,
      fontWeight: FontWeight.w900,
      letterSpacing: -1.2,
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6
              ..color = AppColors.deepBlue,
          ),
        ),
        Text(
          text,
          style: base.copyWith(
            color: color,
            shadows: const [
              Shadow(
                color: AppColors.orange,
                offset: Offset(0, 3),
                blurRadius: 0,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
