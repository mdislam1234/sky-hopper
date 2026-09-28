import 'package:flutter/material.dart';

import '../../core/widgets/sky_hopper_logo.dart';
import '../../core/widgets/sky_page.dart';
import 'settings_controller.dart';
import '../ads/monetization_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.controller,
    required this.onBack,
    this.onButtonFeedback,
    this.monetization,
    super.key,
  });

  final SettingsController controller;
  final VoidCallback onBack;
  final VoidCallback? onButtonFeedback;
  final MonetizationController? monetization;

  void _back() {
    onButtonFeedback?.call();
    onBack();
  }

  Future<void> _privacy(BuildContext context) async {
    onButtonFeedback?.call();
    final shown = await monetization?.showPrivacyOptions() ?? false;
    if (!context.mounted || shown) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Privacy options are unavailable right now.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SkyPage(
    child: AnimatedBuilder(
      animation: Listenable.merge([controller, ?monetization]),
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
                if (monetization?.privacyOptionsRequired ?? false) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy Options'),
                    subtitle: const Text('Review your advertising choices'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _privacy(context),
                  ),
                ],
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
