import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/user_management/data/models/user_model.dart';
import '../../features/user_management/presentation/providers/auth_provider.dart';
import '../theme/theme_mode_provider.dart';

class CineaAppBar extends ConsumerStatefulWidget
    implements PreferredSizeWidget {
  final String title;
  final List<Widget> actions;

  const CineaAppBar({super.key, this.title = 'CINEA', this.actions = const []});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  ConsumerState<CineaAppBar> createState() => _CineaAppBarState();
}

class _CineaAppBarState extends ConsumerState<CineaAppBar> {
  final Color bgIvory = const Color(0xFFF5F3EE);
  final Color surfaceWhite = const Color(0xFFFFFFFF);
  final Color borderSubtle = const Color(0xFFDCD8D0);
  final Color textPrimary = const Color(0xFF1B1B19);
  final Color textMuted = const Color(0xFF716F68);
  final Color accentGold = const Color(0xFF8C692E);

  void _showProfileMenu(BuildContext context, UserModel user) {
    final colors = Theme.of(context).colorScheme;
    final surfaceWhite = colors.surface;
    final textPrimary = colors.onSurface;
    final textMuted = colors.onSurfaceVariant;
    final accentGold = colors.primary;
    final isAdmin = user.role.toLowerCase() == 'admin';

    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête Profil
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: accentGold.withAlpha(40),
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                        style: TextStyle(
                          color: accentGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            user.email,
                            style: TextStyle(color: textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isAdmin
                            ? const Color(0xFFF6EDDA)
                            : const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        user.role.toUpperCase(),
                        style: TextStyle(
                          color: isAdmin ? accentGold : textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const Divider(height: 32),

                // Profile
                ListTile(
                  leading: Icon(
                    Icons.person_outline_rounded,
                    color: textPrimary,
                  ),
                  title: const Text(
                    'Mon Profil',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    user.email,
                    style: TextStyle(color: textMuted, fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/profile');
                  },
                ),

                // Option 2 : ESPACE ADMIN (Uniquement si rôle = admin)
                if (isAdmin) ...[
                  ListTile(
                    leading: Icon(
                      Icons.admin_panel_settings_outlined,
                      color: accentGold,
                    ),
                    title: Text(
                      'Gestion des Comptes & Rôles',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: accentGold,
                      ),
                    ),
                    subtitle: const Text(
                      'Modération des membres & privilèges',
                      style: TextStyle(fontSize: 11),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push('/module/user-management');
                    },
                  ),
                ],

                // Option 3 : Déconnexion
                ListTile(
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFF96443C),
                  ),
                  title: const Text(
                    'Se déconnecter',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF96443C),
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    // 🟢 Déconnexion synchronisée via Riverpod
                    await ref.read(authProvider.notifier).signOut();
                    if (context.mounted) {
                      context.go('/');
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final surfaceWhite = colors.surface;
    final borderSubtle = colors.outlineVariant;
    final textPrimary = colors.onSurface;
    final accentGold = colors.primary;
    final bgIvory = Theme.of(context).scaffoldBackgroundColor;
    final authState = ref.watch(authProvider);
    final userModel = authState.user;
    final isLoading = authState.isLoading;

    return AppBar(
      backgroundColor: surfaceWhite,
      elevation: 0,
      shape: Border(bottom: BorderSide(color: borderSubtle, width: 1)),
      title: Text(
        widget.title,
        style: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
      actions: [
        ...widget.actions,
        PopupMenuButton<ThemeMode>(
          tooltip: 'Theme',
          icon: Icon(
            Theme.of(context).brightness == Brightness.dark
                ? Icons.dark_mode_outlined
                : Icons.light_mode_outlined,
          ),
          onSelected: (mode) =>
              ref.read(themeModeProvider.notifier).setThemeMode(mode),
          itemBuilder: (context) => const [
            PopupMenuItem(value: ThemeMode.system, child: Text('System theme')),
            PopupMenuItem(value: ThemeMode.light, child: Text('Light theme')),
            PopupMenuItem(value: ThemeMode.dark, child: Text('Dark theme')),
          ],
        ),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (userModel != null) ...[
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: InkWell(
              onTap: () => _showProfileMenu(context, userModel),
              borderRadius: BorderRadius.circular(20),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: accentGold.withAlpha(40),
                child: Text(
                  userModel.name.isNotEmpty
                      ? userModel.name[0].toUpperCase()
                      : 'U',
                  style: TextStyle(
                    color: accentGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton.icon(
              onPressed: () => context.push('/auth/login'),
              icon: Icon(Icons.login_rounded, size: 16, color: accentGold),
              label: Text(
                'Connexion',
                style: TextStyle(
                  color: accentGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: bgIvory,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
