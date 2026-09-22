import 'package:flutter/material.dart';

import '../../core/widgets/sky_page.dart';
import '../../core/widgets/sky_hopper_logo.dart';
import 'auth_controller.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({required this.controller, super.key});
  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    final unavailable = controller.stage == AuthStage.unconfigured;
    return SkyPage(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SkyHopperLogo(),
          const SizedBox(height: 16),
          Text(
            'Jump beyond the clouds',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          const Text(
            'Sign in to save your scores, coins, skins, and progress.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: unavailable || controller.signingIn
                ? null
                : controller.signIn,
            child: Text(
              controller.signingIn ? 'Opening Google…' : 'Continue with Google',
              textAlign: TextAlign.center,
            ),
          ),
          if (controller.signingIn) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            const Text(
              'Finish sign-in in your browser. If you closed it, cancel to try again.',
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: controller.cancelPendingSignIn,
              child: const Text('Cancel sign-in'),
            ),
          ],
          if (unavailable) ...[
            const SizedBox(height: 20),
            const Text(
              'Sign-in is currently unavailable. Please try again later.',
              textAlign: TextAlign.center,
            ),
          ],
          if (controller.message != null) ...[
            const SizedBox(height: 20),
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
