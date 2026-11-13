import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/user_management/presentation/providers/auth_provider.dart';
import '../branding.dart';

/// Side menu: every part of the app, grouped by what the user wants to do.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({required this.currentPath, super.key});

  final String currentPath;

  /// Main tabs are opened with `go` (they replace the current tab);
  /// other pages are pushed so the back arrow returns here.
  static const _tabPaths = {'/', '/search', '/for-you', '/lists', '/profile'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final isAdmin = user?.role.toLowerCase() == 'admin';
    final colors = Theme.of(context).colorScheme;
    final current = currentPath;

    void open(String path) {
      Navigator.of(context).pop();
      if (_tabPaths.contains(path)) {
        context.go(path);
      } else {
        context.push(path);
      }
    }

    Widget item(IconData icon, String label, String path) {
      final selected = current == path;
      return ListTile(
        leading: Icon(icon, color: selected ? colors.primary : null),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected ? colors.primary : null,
          ),
        ),
        selected: selected,
        selectedTileColor: colors.primary.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () => open(path),
      );
    }

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: colors.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
    );

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              child: Row(
                children: [
                  const BrandLogo(size: 26),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            if (user != null)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: colors.primary.withValues(alpha: 0.2),
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  user.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(user.email, overflow: TextOverflow.ellipsis),
                onTap: () => open('/profile'),
              )
            else
              Padding(
                padding: const EdgeInsets.all(8),
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/login');
                  },
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Sign in'),
                ),
              ),
            section('Discover'),
            item(Icons.home_rounded, 'Home', '/'),
            item(Icons.local_movies_outlined, 'All movies', '/movies'),
            item(Icons.search_rounded, 'Search', '/search'),
            item(Icons.auto_awesome, 'For You', '/for-you'),
            section('My library'),
            item(Icons.video_library_outlined, 'My lists', '/lists'),
            item(Icons.public, 'Community lists', '/lists/community'),
            item(
              Icons.bookmark_border_rounded,
              'Favorites & watchlist',
              '/collection',
            ),
            item(
              Icons.star_border_rounded,
              'My ratings & reviews',
              '/my-ratings',
            ),
            section('Account'),
            item(Icons.person_outline_rounded, 'Profile', '/profile'),
            item(
              Icons.workspace_premium_outlined,
              'Subscription',
              '/subscription',
            ),
            if (isAdmin) ...[
              section('Administration'),
              item(
                Icons.manage_accounts_outlined,
                'Users',
                '/module/user-management',
              ),
              item(
                Icons.receipt_long_outlined,
                'Subscriptions',
                '/admin/subscriptions',
              ),
            ],
            if (user != null) ...[
              const Divider(height: 32),
              ListTile(
                leading: Icon(Icons.logout_rounded, color: colors.error),
                title: Text('Sign out', style: TextStyle(color: colors.error)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  await ref.read(authProvider.notifier).signOut();
                  if (context.mounted) context.go('/');
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
