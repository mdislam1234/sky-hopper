import 'package:flutter/material.dart';

import '../../core/widgets/sky_page.dart';
import '../../core/widgets/sky_hopper_logo.dart';
import 'auth_controller.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({required this.controller, super.key});
  final AuthController controller;

  @override
  Widget build(BuildContext context) {
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
            'Game services are unavailable. Check the app configuration and try again.',
            textAlign: TextAlign.center,
          ),
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
