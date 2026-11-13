import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/user_management/presentation/providers/auth_provider.dart';
import 'app_drawer.dart';

/// Scaffold of the main tabs: lets any page open the side menu.
final appShellScaffoldKey = GlobalKey<ScaffoldState>();

class _Tab {
  const _Tab(this.path, this.label, this.icon, this.selectedIcon);
  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _tabs = [
  _Tab('/', 'Home', Icons.home_outlined, Icons.home_rounded),
  _Tab('/discover', 'Search', Icons.search_rounded, Icons.search_rounded),
  _Tab('/for-you', 'For You', Icons.auto_awesome_outlined, Icons.auto_awesome),
  _Tab(
    '/lists',
    'My Lists',
    Icons.video_library_outlined,
    Icons.video_library_rounded,
  ),
  _Tab(
    '/profile',
    'Profile',
    Icons.person_outline_rounded,
    Icons.person_rounded,
  ),
];

/// Main tabs with a bottom bar (Netflix / Disney+ style) and a side menu
/// giving access to every other part of the app.
class AppShell extends ConsumerWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  int get _index {
    for (var i = _tabs.length - 1; i > 0; i--) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authProvider).user != null;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      key: appShellScaffoldKey,
      drawer: AppDrawer(currentPath: location),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        height: 68,
        backgroundColor: colors.surface.withValues(alpha: 0.96),
        indicatorColor: colors.primary.withValues(alpha: 0.18),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) {
          final tab = _tabs[i];
          if (tab.path == '/profile' && !signedIn) {
            context.push('/login');
          } else {
            context.go(tab.path);
          }
        },
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon, color: colors.primary),
              label: tab.path == '/profile' && !signedIn
                  ? 'Sign in'
                  : tab.label,
            ),
        ],
      ),
    );
  }
}

/// Menu button for the app bar of a main tab; null when the page can go back
/// (the default back arrow is kept) or outside the main tabs.
Widget? shellMenuButton(BuildContext context) {
  if (Navigator.of(context).canPop()) return null;
  if (appShellScaffoldKey.currentState == null) return null;
  return IconButton(
    tooltip: 'Menu',
    icon: const Icon(Icons.menu_rounded),
    onPressed: () => appShellScaffoldKey.currentState?.openDrawer(),
  );
}
