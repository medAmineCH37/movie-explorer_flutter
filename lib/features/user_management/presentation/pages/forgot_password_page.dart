import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _message;
  String? _error;

  final Color bgIvory = const Color(0xFFF5F3EE);
  final Color surfaceWhite = const Color(0xFFFFFFFF);
  final Color textPrimary = const Color(0xFF1B1B19);
  final Color accentGold = const Color(0xFF8C692E);

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleForgotPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _message = null;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailController.text.trim(),
        redirectTo: 'io.supabase.cinea://reset-password/',
      );

      if (!mounted) return;

      setState(() {
        _message = "✓ Email d'activation envoyé dans votre boîte Mailtrap. Redirection dans 3 secondes...";
      });

      // 🟢 Redirection automatique vers la connexion après 3 secondes
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          context.go('/login');
        }
      });
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = "Une erreur est survenue : $e");
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 18),
          onPressed: () => context.go('/login'),
        ),
      ),
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
                  Icon(Icons.lock_reset_rounded, size: 64, color: accentGold),
                  const SizedBox(height: 20),
                  Text(
                    'RÉCUPÉRATION COMPTE',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: accentGold, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Mot de passe oublié',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      labelText: 'VOTRE ADRESSE E-MAIL',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (val) => val == null || !val.contains('@') ? 'Entrez une adresse valide.' : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleForgotPassword,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: textPrimary,
                        foregroundColor: surfaceWhite,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                          : const Text('ENVOYER LE LIEN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
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
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF96443C), fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F2EB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2E6045).withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF2E6045), fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/login'),
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('REVENIR DE SUITE À LA CONNEXION'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accentGold,
                        side: BorderSide(color: accentGold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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