import 'package:flutter/material.dart';

import 'app_drawer.dart';

/// Scaffold wrapping every page: gives each page the side menu.
final appShellScaffoldKey = GlobalKey<ScaffoldState>();

class AppShell extends StatelessWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: appShellScaffoldKey,
      drawer: AppDrawer(currentPath: location),
      body: child,
    );
  }
}

/// App bar leading for every page: a back arrow (when the page can go back
/// or [onBack] is given) followed by the menu button.
class ShellLeading extends StatelessWidget {
  const ShellLeading({super.key, this.onBack, this.color});

  /// Custom back action; by default the arrow pops the current page.
  final VoidCallback? onBack;
  final Color? color;

  static bool _hasBack(BuildContext context, VoidCallback? onBack) =>
      onBack != null || Navigator.of(context).canPop();

  @override
  Widget build(BuildContext context) {
    final hasBack = _hasBack(context, onBack);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasBack)
          IconButton(
            tooltip: 'Back',
            icon: Icon(Icons.arrow_back_rounded, color: color),
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          ),
        IconButton(
          tooltip: 'Menu',
          icon: Icon(Icons.menu_rounded, color: color),
          onPressed: () => appShellScaffoldKey.currentState?.openDrawer(),
        ),
      ],
    );
  }
}

/// Width to give `AppBar.leadingWidth` so [ShellLeading] fits.
double shellLeadingWidth(BuildContext context, {bool customBack = false}) =>
    ShellLeading._hasBack(context, customBack ? () {} : null) ? 100 : 56;

/// Kept for existing call sites: the menu (and back) buttons.
Widget? shellMenuButton(BuildContext context) => const ShellLeading();
