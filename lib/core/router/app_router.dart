import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/home_page.dart';
import '../../app/module_placeholder_page.dart';
import '../../features/ai_assistant_recommendations/presentation/pages/ai_assistant_recommendations_page.dart';
import '../../features/movie_discovery/presentation/pages/movie_search_page.dart';
import '../../features/movie_management/presentation/pages/movie_details_page.dart';
import '../../features/personal_collection/presentation/pages/collection_page.dart';
import '../../features/user_management/presentation/pages/forgot_password_page.dart';
import '../../features/user_management/presentation/pages/login_page.dart';
import '../../features/user_management/presentation/pages/profile_page.dart';
import '../../features/user_management/presentation/pages/register_page.dart';
import '../../features/user_management/presentation/pages/reset_password_page.dart';
import '../../features/user_management/presentation/pages/user_detail_page.dart';
import '../../features/user_management/presentation/pages/user_management_page.dart';
import '../../features/user_management/presentation/providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),

      // 🟢 ALIAS DE SÉCURITÉ POUR ÉVITER LES ERREURS GOEXCEPTION LORS DE LA DÉCONNEXION
      GoRoute(
        path: '/auth/login',
        redirect: (context, state) => '/login',
      ),
      GoRoute(
        path: '/auth/register',
        redirect: (context, state) => '/register',
      ),

      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordPage(),
      ),
      GoRoute(
        path: '/collection',
        builder: (context, state) => const CollectionPage(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/ai-assistant',
        builder: (context, state) => const AiAssistantRecommendationsPage(),
      ),

      // Route du tableau principal d'administration
      GoRoute(
        path: '/module/user-management',
        builder: (context, state) => const UserManagementPage(),
      ),

      // Route de la fiche détaillée par ID utilisateur
      GoRoute(
        path: '/module/user-management/:id',
        builder: (context, state) {
          final userId = state.pathParameters['id'] ?? '';
          return UserDetailPage(userId: userId);
        },
      ),

      GoRoute(
        path: '/movie/:movieId',
        builder: (context, state) {
          final movieId = int.tryParse(state.pathParameters['movieId'] ?? '');
          if (movieId == null) {
            return const Scaffold(
              body: Center(child: Text('ID de film invalide')),
            );
          }
          return MovieDetailsPage(movieId: movieId);
        },
      ),

      // Catch-all pour les autres modules placeholder
      GoRoute(
        path: '/module/:moduleId',
        builder: (context, state) {
          final id = state.pathParameters['moduleId'] ?? '';
          if (id == 'user-management') return const UserManagementPage();
          if (id == 'recommendations-custom-lists') {
            return const AiAssistantRecommendationsPage();
          }
          return ModulePlaceholderPage(moduleId: id);
        },
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const MovieSearchPage(),
      ),
    ],
    redirect: (context, state) {
      final isLoggedIn = authState.user != null;
      final loc = state.matchedLocation;

      final isAuthPage = loc == '/login' ||
          loc == '/register' ||
          loc == '/forgot-password' ||
          loc == '/reset-password' ||
          loc == '/auth/login' ||
          loc == '/auth/register';

      // 1. Redirige les visiteurs non connectés qui tentent d'accéder à une route privée vers /login
      if (!isLoggedIn && !isAuthPage && loc != '/') {
        return '/login';
      }

      // 2. Redirige les utilisateurs connectés hors des pages d'authentification vers l'accueil
      if (isLoggedIn && isAuthPage) {
        return '/';
      }

      // 🟢 3. Enforce strict l'accès au module d'administration aux rôles admin uniquement
      final role = authState.user?.role.toLowerCase() ?? '';
      if (loc.startsWith('/module/user-management') && role != 'admin') {
        return '/';
      }

      return null;
    },
  );
});