import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/user_management/presentation/pages/forgot_password_page.dart';
import '../../features/user_management/presentation/pages/reset_password_page.dart';

import '../../app/home_page.dart';
import '../../app/module_placeholder_page.dart';
import '../../features/movie_management/presentation/pages/movie_details_page.dart';
import '../../features/movie_discovery/presentation/pages/movie_search_page.dart';
import '../../features/user_management/presentation/pages/login_page.dart';
import '../../features/user_management/presentation/pages/register_page.dart';
import '../../features/user_management/presentation/pages/profile_page.dart';
import '../../features/ai_assistant_recommendations/presentation/pages/ai_assistant_recommendations_page.dart';
import '../../features/user_management/presentation/providers/auth_provider.dart';
import '../../features/personal_collection/presentation/pages/collection_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomePage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterPage()),
      GoRoute(path: '/collection', builder: (context, state) => const CollectionPage()),
      GoRoute(path: '/profile', builder: (context, state) => const ProfilePage()),
      GoRoute(path: '/ai-assistant', builder: (context, state) => const AiAssistantRecommendationsPage()),
      GoRoute(
        path: '/movie/:movieId',
        builder: (context, state) {
          final movieId = int.tryParse(state.pathParameters['movieId'] ?? '');
          if (movieId == null) return const Scaffold(body: Center(child: Text('Invalid movie ID')));
          return MovieDetailsPage(movieId: movieId);
        },
      ),
      GoRoute(
        path: '/module/:moduleId',
        builder: (context, state) {
          final id = state.pathParameters['moduleId'] ?? '';
          if (id == 'user-management') return const ProfilePage();
          if (id == 'recommendations-custom-lists') return const AiAssistantRecommendationsPage();
          return ModulePlaceholderPage(moduleId: id);
        },
      ),
      GoRoute(path: '/search', builder: (context, state) => const MovieSearchPage()),
    ],
    redirect: (context, state) {
      final isLoggedIn = authState.user != null;
      final loc = state.matchedLocation;
      if (!isLoggedIn && loc != '/login' && loc != '/register') return '/login';
      if (isLoggedIn && (loc == '/login' || loc == '/register')) return '/';
      return null;
    },
  );
});
