import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/user_model.dart';
import '../../data/services/auth_service.dart';
import '../providers/auth_provider.dart';

bool _globalPushNotificationsEnabled = false;

class UserManagementPage extends ConsumerStatefulWidget {
  const UserManagementPage({super.key});

  @override
  ConsumerState<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends ConsumerState<UserManagementPage> {
  final AuthService _authService = AuthService();
  List<UserModel> _users = [];
  bool _isLoading = true;

  Color get bgIvory => Theme.of(context).scaffoldBackgroundColor;
  Color get surfaceWhite => Theme.of(context).colorScheme.surface;
  Color get borderSubtle => Theme.of(context).colorScheme.outlineVariant;
  Color get textPrimary => Theme.of(context).colorScheme.onSurface;
  Color get textMuted => Theme.of(context).colorScheme.onSurfaceVariant;
  Color get accentGold => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _authService.getAllUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _navigateToDetail(String userId) async {
    await context.push('/module/user-management/$userId');
    if (!mounted) return;
    await _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bgIvory = Theme.of(context).scaffoldBackgroundColor;
    final surfaceWhite = colors.surface;
    final borderSubtle = colors.outlineVariant;
    final textPrimary = colors.onSurface;
    final textMuted = colors.onSurfaceVariant;
    final accentGold = colors.primary;
    final authState = ref.watch(authProvider);
    final currentUser = authState.user;

    if (currentUser == null) {
      Future.microtask(() {
        if (context.mounted) context.go('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (currentUser.role.toLowerCase() != 'admin') {
      Future.microtask(() {
        if (context.mounted) context.go('/');
      });
      return const Scaffold(
        body: Center(child: Text('Accès refusé. Redirection...')),
      );
    }

    final currentAdminId = _authService.currentUser?.id;

    return Scaffold(
      backgroundColor: bgIvory,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: borderSubtle, width: 1)),
        title: Text(
          'Gestion des Comptes & Rôles',
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
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
      body: RefreshIndicator(
        onRefresh: _loadUsers,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Panneau de modération et d\'administration de la plateforme CINEA',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderSubtle),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ABONNEMENT AUX NOTIFICATIONS',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Activez la réception des alertes système en tâche de fond pour recevoir les notifications de modération.',
                            style: TextStyle(color: textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _globalPushNotificationsEnabled =
                              !_globalPushNotificationsEnabled;
                        });
                      },
                      icon: Icon(
                        _globalPushNotificationsEnabled
                            ? Icons.notifications_active
                            : Icons.notifications_off,
                        size: 14,
                        color: accentGold,
                      ),
                      label: Text(
                        _globalPushNotificationsEnabled
                            ? 'DÉSACTIVER PUSH'
                            : 'ACTIVER PUSH',
                        style: TextStyle(
                          color: accentGold,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        side: BorderSide(color: accentGold),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_users.isEmpty)
                Container(
                  padding: const EdgeInsets.all(30),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: surfaceWhite,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('Aucun utilisateur trouvé.'),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _users.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final isAdmin = user.role.toLowerCase() == 'admin';
                    final isSelf = user.id == currentAdminId;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surfaceWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: bgIvory,
                                child: Text(
                                  user.name.isNotEmpty
                                      ? user.name[0].toUpperCase()
                                      : 'U',
                                  style: TextStyle(
                                    color: accentGold,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.name,
                                      style: TextStyle(
                                        color: textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isAdmin
                                            ? const Color(0xFFF6EDDA)
                                            : const Color(0xFFF0F0F0),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        user.role.toUpperCase(),
                                        style: TextStyle(
                                          color: isAdmin
                                              ? accentGold
                                              : textMuted,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.chevron_right_rounded,
                                  color: textMuted,
                                ),
                                onPressed: () => _navigateToDetail(user.id),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              Icon(
                                Icons.email_outlined,
                                size: 14,
                                color: textMuted,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  user.email.isNotEmpty
                                      ? user.email
                                      : 'Email non disponible',
                                  style: TextStyle(
                                    color: textMuted,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: user.valide
                                        ? const Color(0xFF2E6045)
                                        : const Color(0xFF96443C),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    user.valide ? 'Validé' : 'Bloqué',
                                    style: TextStyle(
                                      color: user.valide
                                          ? const Color(0xFF2E6045)
                                          : const Color(0xFF96443C),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton(
                                      onPressed: () async {
                                        final newStatus = !user.valide;
                                        await _authService.toggleUserValidation(
                                          user.id,
                                          user.valide,
                                        );
                                        if (!mounted) return;
                                        setState(() {
                                          _users[index] = UserModel(
                                            id: user.id,
                                            name: user.name,
                                            email: user.email,
                                            role: user.role,
                                            valide: newStatus,
                                          );
                                        });
                                      },
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                        ),
                                      ),
                                      child: Text(
                                        user.valide ? 'Bloquer' : 'Activer',
                                        style: TextStyle(
                                          color: user.valide
                                              ? const Color(0xFF96443C)
                                              : const Color(0xFF2E6045),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    OutlinedButton(
                                      onPressed: isSelf
                                          ? null
                                          : () async {
                                              final messenger =
                                                  ScaffoldMessenger.of(context);
                                              final nextRole = isAdmin
                                                  ? 'user'
                                                  : 'admin';

                                              await _authService.updateUserRole(
                                                user.id,
                                                nextRole,
                                              );
                                              if (!mounted) return;

                                              setState(() {
                                                _users[index] = UserModel(
                                                  id: user.id,
                                                  name: user.name,
                                                  email: user.email,
                                                  role: nextRole,
                                                  valide: user.valide,
                                                );
                                              });

                                              messenger.showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Rôle modifié en : ${nextRole.toUpperCase()}',
                                                  ),
                                                  duration: const Duration(
                                                    seconds: 2,
                                                  ),
                                                ),
                                              );
                                            },
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                        ),
                                        side: BorderSide(
                                          color: isSelf
                                              ? borderSubtle
                                              : accentGold,
                                        ),
                                      ),
                                      child: Text(
                                        isAdmin
                                            ? 'RÉTROGRADER'
                                            : 'NOMMER ADMIN 🛡️',
                                        style: TextStyle(
                                          color: isSelf
                                              ? textMuted
                                              : accentGold,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
