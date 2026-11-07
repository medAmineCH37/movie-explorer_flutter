import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  final Color bgIvory = const Color(0xFFF5F3EE);
  final Color surfaceWhite = const Color(0xFFFFFFFF);
  final Color textPrimary = const Color(0xFF1B1B19);
  final Color accentGold = const Color(0xFF8C692E);

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text.trim()),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Votre nouveau mot de passe secret a été configuré avec succès !'),
          backgroundColor: Color(0xFF2E6045),
        ),
      );
      context.go('/login');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = "Une erreur technique est survenue.");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgIvory,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.verified_user_rounded, size: 64, color: accentGold),
                  const SizedBox(height: 20),
                  Text(
                    'SÉCURITÉ DU COMPTE',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: accentGold, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Nouveau mot de passe',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      labelText: 'SAISISSEZ VOTRE NOUVELLE CLÉ',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                    validator: (val) => val == null || val.length < 6 ? 'Le mot de passe doit faire au moins 6 caractères.' : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleResetPassword,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: textPrimary,
                        foregroundColor: surfaceWhite,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('CONFIRMER LA MUTATION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6EDDA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF86651F).withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        '⚠️ $_error',
                        style: const TextStyle(color: Color(0xFF86651F), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}