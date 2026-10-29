
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../../app/home_page.dart';
import '../../app/module_placeholder_page.dart';
import '../../features/movie_management/presentation/pages/movie_details_page.dart';
import '../../features/movie_discovery/presentation/pages/movie_search_page.dart';
import '../../features/user_management/presentation/pages/login_page.dart';
import '../../features/user_management/presentation/pages/register_page.dart';

final appRouter = GoRouter(
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
    GoRoute(
      path: '/movie/:movieId',
      builder: (context, state) {
        final movieId = int.tryParse(
          state.pathParameters['movieId'] ?? '',
        );

        if (movieId == null) {
          return const Scaffold(
            body: Center(
              child: Text('Invalid movie ID'),
            ),
          );
        }

        return MovieDetailsPage(movieId: movieId);
      },
    ),
    GoRoute(
      path: '/module/:moduleId',
      builder: (context, state) {
        return ModulePlaceholderPage(
          moduleId: state.pathParameters['moduleId'] ?? '',
        );
      },
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) => const MovieSearchPage(),
    ),
  ],
);
