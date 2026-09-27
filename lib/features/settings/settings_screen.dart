import 'package:flutter/material.dart';

import '../../core/widgets/sky_hopper_logo.dart';
import '../../core/widgets/sky_page.dart';
import 'settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.controller,
    required this.onBack,
    this.onButtonFeedback,
    super.key,
  });

  final SettingsController controller;
  final VoidCallback onBack;
  final VoidCallback? onButtonFeedback;

  void _back() {
    onButtonFeedback?.call();
    onBack();
  }

  @override
  Widget build(BuildContext context) => SkyPage(
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SkyHopperLogo(),
          const SizedBox(height: 18),
          Text(
            'SETTINGS',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 18),
          Card(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  title: const Text('Music'),
                  subtitle: const Text('Biome-aware background theme'),
                  secondary: const Icon(Icons.music_note_rounded),
                  value: controller.value.musicEnabled,
                  onChanged: controller.setMusicEnabled,
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  title: const Text('Sound Effects'),
                  subtitle: const Text('Gameplay and menu feedback'),
                  secondary: const Icon(Icons.volume_up_rounded),
                  value: controller.value.soundEnabled,
                  onChanged: controller.setSoundEnabled,
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  title: const Text('Haptics'),
                  subtitle: const Text('Supported mobile devices only'),
                  secondary: const Icon(Icons.vibration_rounded),
                  value: controller.value.hapticsEnabled,
                  onChanged: controller.setHapticsEnabled,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _back,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('BACK'),
          ),
        ],
      ),
    ),
  );
}
