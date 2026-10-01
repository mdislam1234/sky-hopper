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
    final guest = controller.isGuest;
    final avatar = Uri.tryParse(controller.avatarUrl ?? '');
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
            controller.playerName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          if (guest) ...[
            const SizedBox(height: 12),
            Text(
              'Playing as Guest',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ] else if (controller.user?.email != null) ...[
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
          if (guest) ...[
            const Text(
              'Sign in to protect your progress and restore it on another device.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: controller.signingIn ? null : controller.signIn,
              icon: const Icon(Icons.login_rounded),
              label: Text(
                controller.signingIn
                    ? 'Opening Google…'
                    : 'Sign in with Google',
              ),
            ),
            if (controller.signingIn) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
              const SizedBox(height: 10),
              const Text(
                'Finish sign-in in your browser to protect this guest progress.',
                textAlign: TextAlign.center,
              ),
              TextButton(
                onPressed: controller.cancelPendingSignIn,
                child: const Text('Cancel sign-in'),
              ),
            ],
            const SizedBox(height: 16),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Guest progress may be lost if you uninstall the app or clear app data.',
                  ),
                ),
              ],
            ),
          ] else
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
