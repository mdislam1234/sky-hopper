import 'package:flutter/material.dart';

import '../../core/widgets/sky_page.dart';
import 'auth_controller.dart';

class AccountDeletedScreen extends StatelessWidget {
  const AccountDeletedScreen({required this.controller, super.key});

  final AuthController controller;

  @override
  Widget build(BuildContext context) => SkyPage(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle_outline_rounded, size: 72),
        const SizedBox(height: 20),
        Text(
          'ACCOUNT DELETED',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        const Text(
          'Your Sky Hopper account and saved progress have been deleted.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: controller.continuingAsGuest
              ? null
              : controller.continueAsGuest,
          child: controller.continuingAsGuest
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              : const Text('CONTINUE AS GUEST'),
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
