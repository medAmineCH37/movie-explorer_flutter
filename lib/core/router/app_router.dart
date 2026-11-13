import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/home_page.dart';
import '../../app/module_placeholder_page.dart';
import '../../features/movie_management/data/models/movie_category.dart';
import '../../features/movie_management/presentation/pages/movie_catalog_page.dart';
import '../../features/movie_management/presentation/pages/movie_details_page.dart';
import '../../features/movie_discovery/presentation/pages/movie_search_page.dart';
import '../../features/personal_collection/presentation/pages/collection_page.dart';
import '../../features/subscription_management/presentation/pages/subscription_page.dart';
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
      GoRoute(path: '/', builder: (context, state) => const HomePage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(path: '/auth/login', redirect: (context, state) => '/login'),
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
        path: '/subscription',
        builder: (context, state) => const SubscriptionPage(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/module/user-management',
        builder: (context, state) => const UserManagementPage(),
      ),
      GoRoute(
        path: '/module/user-management/:id',
        builder: (context, state) =>
            UserDetailPage(userId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/movies',
        builder: (context, state) => MovieCatalogPage(
          initialCategory: MovieCategory.fromSlug(
            state.uri.queryParameters['category'],
          ),
        ),
      ),
      GoRoute(
        path: '/movie/:movieId',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['movieId'] ?? '');
          return id == null
              ? const Scaffold(body: Center(child: Text('Invalid movie ID')))
              : MovieDetailsPage(movieId: id);
        },
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const MovieSearchPage(),
      ),
      GoRoute(
        path: '/module/:moduleId',
        builder: (context, state) => ModulePlaceholderPage(
          moduleId: state.pathParameters['moduleId'] ?? '',
        ),
      ),
    ],
    redirect: (context, state) {
      final location = state.matchedLocation;
      final authPage = {
        '/login',
        '/register',
        '/forgot-password',
        '/reset-password',
        '/auth/login',
        '/auth/register',
      }.contains(location);
      if (authState.isLoading) return null;
      if (authState.user == null &&
          location != '/' &&
          !authPage &&
          location != '/movie' &&
          !location.startsWith('/movie/')) {
        return Uri(
          path: '/login',
          queryParameters: {'redirect': state.uri.toString()},
        ).toString();
      }
      if (authState.user != null && authPage) return '/';
      if (location.startsWith('/module/user-management') &&
          authState.user?.role.toLowerCase() != 'admin') {
        return '/';
      }
      return null;
    },
  );
});
