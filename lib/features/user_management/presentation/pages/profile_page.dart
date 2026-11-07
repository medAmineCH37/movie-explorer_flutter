import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  final Color bgIvory = const Color(0xFFF5F3EE);
  final Color surfaceWhite = const Color(0xFFFFFFFF);
  final Color borderSubtle = const Color(0xFFDCD8D0);
  final Color textPrimary = const Color(0xFF1B1B19);
  final Color textMuted = const Color(0xFF716F68);
  final Color accentGold = const Color(0xFF8C692E);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 18),
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
              style: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              'Rôle : ${user.role.toUpperCase()}',
              style: TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: surfaceWhite,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: borderSubtle),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF272116).withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Abonnement Streaming',
                        style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Chip(
                        label: Text(
                          user.isSubscribed ? '✨ PREMIUM' : '👤 GRATUIT',
                          style: TextStyle(
                            color: user.isSubscribed ? const Color(0xFF2E6045) : const Color(0xFF86651F),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: user.isSubscribed ? const Color(0xFFE8F2EB) : const Color(0xFFF6EDDA),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.isSubscribed
                        ? "Vous profitez de l'accès Premium illimité CINEA pour voir tout le catalogue TMDB en HD."
                        : "Votre accès est suspendu. Réabonnez-vous pour débloquer les flux vidéos.",
                    style: TextStyle(color: textMuted, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => ref.read(authProvider.notifier).toggleSubscription(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: accentGold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        user.isSubscribed ? 'RÉSILIER MON ACCÈS' : 'RÉACTIVER ACCÈS PREMIUM ✨',
                        style: TextStyle(color: accentGold, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 32),
            ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFF96443C)),
              title: const Text(
                'Se déconnecter de la session',
                style: TextStyle(color: Color(0xFF96443C), fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onTap: () async {
                final router = GoRouter.of(context);
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  router.go('/login');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}