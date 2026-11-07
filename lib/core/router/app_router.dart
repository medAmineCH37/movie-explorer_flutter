import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../../app/home_page.dart';
import '../../app/module_placeholder_page.dart';
import '../../features/movie_management/presentation/pages/movie_details_page.dart';
import '../../features/movie_discovery/presentation/pages/movie_search_page.dart';
import '../../features/user_management/presentation/pages/login_page.dart';
import '../../features/user_management/presentation/pages/register_page.dart';
import '../../features/personal_collection/presentation/pages/collection_page.dart';
import '../../features/recommendations_custom_lists/presentation/pages/community_lists_page.dart';
import '../../features/recommendations_custom_lists/presentation/pages/for_you_page.dart';
import '../../features/recommendations_custom_lists/presentation/pages/list_detail_page.dart';
import '../../features/recommendations_custom_lists/presentation/pages/my_lists_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomePage()),
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      path: '/collection',
      builder: (context, state) => const CollectionPage(),
    ),
    GoRoute(
      path: '/movie/:movieId',
      builder: (context, state) {
        final movieId = int.tryParse(state.pathParameters['movieId'] ?? '');

        if (movieId == null) {
          return const Scaffold(body: Center(child: Text('Invalid movie ID')));
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
    GoRoute(path: '/for-you', builder: (context, state) => const ForYouPage()),
    GoRoute(path: '/lists', builder: (context, state) => const MyListsPage()),
    GoRoute(
      path: '/lists/community',
      builder: (context, state) => const CommunityListsPage(),
    ),
    GoRoute(
      path: '/lists/:listId',
      builder: (context, state) {
        final listId = int.tryParse(state.pathParameters['listId'] ?? '');
        if (listId == null) {
          return const Scaffold(body: Center(child: Text('Invalid list ID')));
        }
        return ListDetailPage(listId: listId);
      },
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) => const MovieSearchPage(),
    ),
  ],
);
