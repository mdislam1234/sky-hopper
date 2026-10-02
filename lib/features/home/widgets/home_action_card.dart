import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class HomeActionCard extends StatelessWidget {
  const HomeActionCard({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.accentColor = AppColors.gold,
    this.centered = false,
    this.allowWrap = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color accentColor;
  final bool centered;
  final bool allowWrap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cloud.withValues(alpha: 0.94),
      elevation: 3,
      shadowColor: AppColors.deepBlue.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: centered
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, size: 25, color: accentColor),
                ),
              ),
              const SizedBox(width: 10),
              if (centered)
                Flexible(child: _label(context))
              else
                Expanded(child: _label(context)),
              const SizedBox(width: 6),
              ExcludeSemantics(
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: AppColors.deepBlue.withValues(alpha: 0.32),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(BuildContext context) {
    final text = Text(
      label,
      maxLines: allowWrap ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: AppColors.deepBlue,
        fontWeight: FontWeight.w800,
        height: 1.08,
      ),
    );
    if (allowWrap || centered) return text;
    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(fit: BoxFit.scaleDown, child: text),
    );
  }
}
