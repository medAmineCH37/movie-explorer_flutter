import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/services/auth_service.dart';
import '../providers/auth_provider.dart';


class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final bgIvory = Theme.of(context).scaffoldBackgroundColor;
    final surfaceWhite = colors.surface;
    final borderSubtle = colors.outlineVariant;
    final textPrimary = colors.onSurface;
    final textMuted = colors.onSurfaceVariant;
    final state = ref.watch(authProvider);
    final user = state.user;

    if (user == null) {
      return Scaffold(
        backgroundColor: bgIvory,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Aucune session active."),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('Se connecter'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgIvory,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        centerTitle: false,
        shape: Border(bottom: BorderSide(color: borderSubtle, width: 1)),
        title: Text(
          'Mon Profil CINEA',
          style: TextStyle(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textPrimary,
            size: 18,
          ),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bonjour, ${user.name}',
              style: TextStyle(
                color: textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Rôle : ${user.role.toUpperCase()}',
              style: TextStyle(
                color: textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Profile'),
              subtitle: const Text('Update your display name'),
                onTap: () async {
                  final controller = TextEditingController(text: user.name);

                  final newName = await showDialog<String>(
                    context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text(
                          'Edit Profile',
                          textAlign: TextAlign.center,
                        ),
                        content: SizedBox(
                          width: 350,
                          child: TextField(
                            controller: controller,
                            autofocus: true,
                            decoration: const InputDecoration(
                              labelText: 'Display Name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        actionsAlignment: MainAxisAlignment.spaceBetween,
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, controller.text.trim()),
                            child: const Text('Save'),
                          ),
                        ],
                      ));

                  if (newName == null || newName.isEmpty) {
                    return;
                  }

                  try {
                    await AuthService().updateMyProfile(
                      displayName: newName,
                    );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile updated successfully.'),
                        ),
                      );

                      ref.read(authProvider.notifier).refreshProfile();
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(e.toString()),
                        ),
                      );
                    }
                  }
                },
            ),

            ListTile(
              leading: const Icon(Icons.lock_reset),
              title: const Text('Change Password'),
              subtitle: const Text('Update your account password'),
              onTap: () => context.push('/reset-password'),
            ),

            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: const Text('Subscription Details'),
              subtitle: const Text('View your current subscription'),
              onTap: () => context.push('/subscription'),
            ),

            ListTile(
              leading: const Icon(
                Icons.delete_forever_outlined,
                color: Color(0xFF96443C),
              ),
              title: const Text(
                'Delete My Account',
                style: TextStyle(
                  color: Color(0xFF96443C),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              subtitle: const Text(
                'Permanently remove your account',
              ),
                onTap: () async {
                  final confirmation = await showDialog<String>(
                    context: context,
                    builder: (dialogContext) {
                      final controller = TextEditingController();

                      return AlertDialog(
                        title: const Text('Delete My Account'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'This action is irreversible.\n\nType DELETE to confirm.',
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: controller,
                              decoration: const InputDecoration(
                                labelText: 'Confirmation',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, controller.text.trim()),
                            child: const Text('Delete'),
                          ),
                        ],
                      );
                    },
                  );

                  if (confirmation != 'DELETE') {
                    return;
                  }

                  if (context.mounted) {
                    try {
                      await AuthService().deleteManagedUser(user.id);

                      if (!context.mounted) return;

                      await ref.read(authProvider.notifier).logout();

                      if (!context.mounted) return;

                      context.go('/');

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Account deleted successfully.'),
                        ),
                      );

                      await Future.delayed(const Duration(milliseconds: 500));

                      if (!context.mounted) return;

                      context.go('/');
                    } catch (e) {
                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(e.toString()),
                        ),
                      );
                    }
                  }
                },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFF96443C)),
              title: const Text(
                'Se déconnecter de la session',
                style: TextStyle(
                  color: Color(0xFF96443C),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              onTap: () async {
                final router = GoRouter.of(context);
                await ref.read(authProvider.notifier).logout();
                ref.invalidate(authProvider);
                if (context.mounted) {
                  router.go('/');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
