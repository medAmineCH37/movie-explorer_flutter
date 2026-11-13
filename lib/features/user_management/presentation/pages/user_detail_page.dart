import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/user_model.dart';
import '../../data/services/auth_service.dart';

class UserDetailPage extends StatefulWidget {
  final String userId;
  const UserDetailPage({super.key, required this.userId});

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _hasError = false;

  Color get bgIvory => Theme.of(context).scaffoldBackgroundColor;
  Color get surfaceWhite => Theme.of(context).colorScheme.surface;
  Color get borderSubtle => Theme.of(context).colorScheme.outlineVariant;
  Color get textPrimary => Theme.of(context).colorScheme.onSurface;
  Color get textMuted => Theme.of(context).colorScheme.onSurfaceVariant;
  Color get accentGold => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    _fetchUser();
  }

  Future<void> _fetchUser() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final user = await _authService.getUserById(widget.userId);
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
          _hasError = user == null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bgIvory = Theme.of(context).scaffoldBackgroundColor;
    final surfaceWhite = colors.surface;
    final borderSubtle = colors.outlineVariant;
    final textPrimary = colors.onSurface;
    return Scaffold(
      backgroundColor: bgIvory,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: borderSubtle, width: 1)),
        title: Text(
          'Fiche Membre CinéHub',
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: _currentUser == null
            ? const []
            : [
                IconButton(
                  tooltip: 'Modifier le compte',
                  onPressed: () => _editUser(_currentUser!),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Supprimer le compte',
                  onPressed: _currentUser!.id == _authService.currentUser?.id
                      ? null
                      : () => _confirmDeleteUser(_currentUser!),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                ),
              ],
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textPrimary,
            size: 18,
          ),
          onPressed: () => context.pop(true),
        ),
      ),
      body: _buildContent(),
    );
  }

  Future<void> _editUser(UserModel user) async {
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _EditManagedUserDialog(user: user),
    );
    if (!mounted || values == null) return;

    try {
      await _authService.updateManagedUser(
        userId: user.id,
        displayName: values['displayName']!,
        email: values['email']!,
      );
      if (!mounted) return;
      await _fetchUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Compte mis à jour.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de la mise à jour : $error')),
      );
    }
  }

  Future<void> _confirmDeleteUser(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce compte ?'),
        content: Text(
          'Le compte de ${user.name} (${user.email}) et ses données liées seront supprimés définitivement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _authService.deleteManagedUser(user.id);
      if (mounted) context.pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de la suppression : $error')),
      );
    }
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError || _currentUser == null) {
      return Center(
        child: Text(
          'Compte utilisateur introuvable.',
          style: TextStyle(color: textMuted, fontSize: 14),
        ),
      );
    }

    final user = _currentUser!;
    final isAdmin = user.role.toLowerCase() == 'admin';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: surfaceWhite,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderSubtle),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: accentGold.withAlpha(30),
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                    style: TextStyle(
                      color: accentGold,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email.isNotEmpty
                            ? user.email
                            : 'Adresse e-mail non disponible',
                        style: TextStyle(color: textMuted, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: surfaceWhite,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderSubtle),
            ),
            child: Column(
              children: [
                // ID système sécurisé sans débordement
                _buildDetailRow(
                  'ID Système',
                  user.id,
                  icon: Icons.fingerprint,
                  isIdField: true,
                ),
                const Divider(height: 24),
                _buildDetailRow(
                  'Rôle actuel',
                  user.role.toUpperCase(),
                  badgeColor: isAdmin
                      ? const Color(0xFFF6EDDA)
                      : const Color(0xFFF0F0F0),
                  badgeTextColor: isAdmin ? accentGold : textMuted,
                ),
                const Divider(height: 24),
                _buildDetailRow(
                  'Statut du compte',
                  user.valide ? 'Compte Validé (Actif)' : 'Compte Bloqué',
                  badgeColor: user.valide
                      ? const Color(0xFFE3F0E9)
                      : const Color(0xFFFDE8E6),
                  badgeTextColor: user.valide
                      ? const Color(0xFF2E6045)
                      : const Color(0xFF96443C),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final newStatus = !user.valide;
                    await _authService.toggleUserValidation(
                      user.id,
                      user.valide,
                    );

                    if (!mounted) return;

                    setState(() {
                      _currentUser = UserModel(
                        id: user.id,
                        name: user.name,
                        email: user.email,
                        role: user.role,
                        valide: newStatus,
                      );
                    });

                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          newStatus ? 'Compte activé' : 'Compte bloqué',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                      color: user.valide
                          ? const Color(0xFF96443C)
                          : const Color(0xFF2E6045),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    user.valide ? 'BLOQUER LE COMPTE' : 'ACTIVATION DU COMPTE',
                    style: TextStyle(
                      color: user.valide
                          ? const Color(0xFF96443C)
                          : const Color(0xFF2E6045),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final nextRole = isAdmin ? 'user' : 'admin';
                    await _authService.updateUserRole(user.id, nextRole);

                    if (!mounted) return;

                    setState(() {
                      _currentUser = UserModel(
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
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentGold,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isAdmin ? 'RÉTROGRADER USER' : 'NOMMER ADMIN 🔵',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    IconData? icon,
    Color? badgeColor,
    Color? badgeTextColor,
    bool isIdField = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: textMuted),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        if (badgeColor != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: badgeTextColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        else
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: SelectableText(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: isIdField ? 10 : 12,
                  fontFamily: isIdField ? 'monospace' : null,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _EditManagedUserDialog extends StatefulWidget {
  const _EditManagedUserDialog({required this.user});

  final UserModel user;

  @override
  State<_EditManagedUserDialog> createState() => _EditManagedUserDialogState();
}

class _EditManagedUserDialogState extends State<_EditManagedUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _emailController = TextEditingController(text: widget.user.email);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier le compte'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nom affiché'),
              validator: (value) {
                final name = value?.trim() ?? '';
                if (name.length < 2 || name.length > 80) {
                  return 'Le nom doit contenir entre 2 et 80 caractères.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Adresse e-mail',
                helperText: 'Le changement est appliqué immédiatement.',
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
                  return 'Saisissez une adresse e-mail valide.';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, {
              'displayName': _nameController.text.trim(),
              'email': _emailController.text.trim(),
            });
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
