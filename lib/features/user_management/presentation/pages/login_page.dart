import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_shell.dart';
import '../providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  Color get bgIvory => Theme.of(context).scaffoldBackgroundColor;
  Color get surfaceWhite => Theme.of(context).colorScheme.surface;
  Color get textPrimary => Theme.of(context).colorScheme.onSurface;
  Color get textMuted => Theme.of(context).colorScheme.onSurfaceVariant;
  Color get accentGold => Theme.of(context).colorScheme.primary;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bgIvory = Theme.of(context).scaffoldBackgroundColor;
    final surfaceWhite = colors.surface;
    final textPrimary = colors.onSurface;
    final textMuted = colors.onSurfaceVariant;
    final accentGold = colors.primary;
    final state = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: bgIvory,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const ShellLeading(),
        leadingWidth: shellLeadingWidth(context),
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
                  Center(
                    child: Column(
                      children: [
                        Container(
                          height: 56,
                          width: 56,
                          decoration: BoxDecoration(
                            color: textPrimary,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.movie_filter_outlined,
                              size: 28,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'CINÉHUB',
                          style: TextStyle(
                            color: accentGold,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'SIGN IN',
                    style: TextStyle(
                      color: accentGold,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Welcome back,\nmovie fan',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'E-MAIL ADDRESS',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) => v == null || !v.contains('@')
                        ? 'Enter a valid e-mail.'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'PASSWORD',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Enter your password.' : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: state.isLoading
                          ? null
                          : () async {
                              if (_formKey.currentState!.validate()) {
                                final router = GoRouter.of(context);
                                final requestedRoute = GoRouterState.of(context)
                                    .uri
                                    .queryParameters['redirect'];
                                final ok = await ref
                                    .read(authProvider.notifier)
                                    .login(_email.text.trim(), _password.text);

                                if (!mounted) return;

                                if (ok) {
                                  final destination =
                                      requestedRoute != null &&
                                          requestedRoute.startsWith('/') &&
                                          !requestedRoute.startsWith('//')
                                      ? requestedRoute
                                      : '/';
                                  router.go(destination);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: textPrimary,
                        foregroundColor: surfaceWhite,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: state.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'SIGN IN',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/register'),
                    child: Text(
                      "Create an account",
                      style: TextStyle(
                        color: accentGold,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/forgot-password'),
                    child: Text(
                      "Forgot your password? Reset it",
                      style: TextStyle(
                        fontSize: 12,
                        color: textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (state.error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6EDDA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF86651F).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        state.error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF96443C),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
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
