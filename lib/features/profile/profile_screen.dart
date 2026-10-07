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

  Future<void> _confirmDeletion(BuildContext context) async {
    var deleting = false;
    String? error;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final media = MediaQuery.of(context);
          final maxHeight =
              media.size.height -
              media.padding.vertical -
              media.viewInsets.vertical -
              32;
          final cancelButton = TextButton(
            autofocus: true,
            onPressed: deleting
                ? null
                : () => Navigator.of(dialogContext).pop(),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('CANCEL'),
            ),
          );
          final deleteButton = FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: deleting
                ? null
                : () async {
                    setState(() {
                      deleting = true;
                      error = null;
                    });
                    final deleted = await controller.deleteAccount();
                    if (!dialogContext.mounted) return;
                    if (deleted) {
                      Navigator.of(dialogContext).pop();
                    } else {
                      setState(() {
                        deleting = false;
                        error = controller.deletionError;
                      });
                    }
                  },
            child: deleting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('DELETE ACCOUNT'),
                  ),
          );
          return PopScope(
            canPop: !deleting,
            child: Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 440,
                  maxHeight: maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Delete account?',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'This permanently deletes your Sky Hopper account and saved game progress, including your profile, scores, coins, skins, missions, achievements, streaks, and other account-linked progress. This cannot be undone.',
                              ),
                              if (error != null) ...[
                                const SizedBox(height: 16),
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    error!,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stackActions =
                              constraints.maxWidth < 320 ||
                              media.textScaler.scale(14) > 18;
                          if (stackActions) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(height: 48, child: deleteButton),
                                const SizedBox(height: 8),
                                SizedBox(height: 48, child: cancelButton),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: cancelButton),
                              const SizedBox(width: 8),
                              Expanded(child: deleteButton),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

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
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 20),
          Text('Account', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Permanently remove this account and all saved Sky Hopper progress.',
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
            onPressed: controller.deletingAccount
                ? null
                : () => _confirmDeletion(context),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }
}
