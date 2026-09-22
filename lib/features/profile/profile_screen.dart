import 'package:flutter/material.dart';

import '../../core/widgets/sky_page.dart';
import '../auth/auth_controller.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.controller,
    required this.onBack,
    super.key,
  });
  final AuthController controller;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile!;
    final name = profile.displayName?.trim();
    final avatar = Uri.tryParse(profile.avatarUrl ?? '');
    final showAvatar =
        avatar != null &&
        avatar.scheme == 'https' &&
        avatar.host.isNotEmpty &&
        avatar.userInfo.isEmpty;
    return SkyPage(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Home'),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: ClipOval(
              child: showAvatar
                  ? Image.network(
                      avatar.toString(),
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, stack) =>
                          const Icon(Icons.account_circle_outlined, size: 72),
                    )
                  : const Icon(Icons.account_circle_outlined, size: 72),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name == null || name.isEmpty ? 'Player' : name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          if (controller.user?.email != null) ...[
            const SizedBox(height: 12),
            Text(controller.user!.email!, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
          Text('Coins: ${profile.totalCoins}', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(
            'Selected skin: ${profile.selectedSkin}',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: controller.signingOut ? null : controller.signOut,
            child: Text(controller.signingOut ? 'Signing out…' : 'SIGN OUT'),
          ),
          if (controller.message != null) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(controller.message!, textAlign: TextAlign.center),
            ),
          ],
        ],
      ),
    );
  }
}
