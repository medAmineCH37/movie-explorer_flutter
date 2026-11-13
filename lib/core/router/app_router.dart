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
import '../../features/subscription_management/presentation/pages/admin_subscriptions_page.dart';
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
  final authRefresh = _AuthRouterRefreshListenable();
  ref.listen(authProvider, (_, _) => authRefresh.refresh());

  final router = GoRouter(
    refreshListenable: authRefresh,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            _withBackFallback(context, const HomePage()),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            _withBackFallback(context, const LoginPage()),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) =>
            _withBackFallback(context, const RegisterPage()),
      ),
      GoRoute(path: '/auth/login', redirect: (context, state) => '/login'),
      GoRoute(
        path: '/auth/register',
        redirect: (context, state) => '/register',
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) =>
            _withBackFallback(context, const ForgotPasswordPage()),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) =>
            _withBackFallback(context, const ResetPasswordPage()),
      ),
      GoRoute(
        path: '/collection',
        builder: (context, state) =>
            _withBackFallback(context, const CollectionPage()),
      ),
      GoRoute(
        path: '/subscription',
        builder: (context, state) =>
            _withBackFallback(context, const SubscriptionPage()),
      ),
      GoRoute(
        path: '/admin/subscriptions',
        builder: (context, state) =>
            _withBackFallback(context, const AdminSubscriptionsPage()),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) =>
            _withBackFallback(context, const ProfilePage()),
      ),
      GoRoute(
        path: '/module/user-management',
        builder: (context, state) =>
            _withBackFallback(context, const UserManagementPage()),
      ),
      GoRoute(
        path: '/module/user-management/:id',
        builder: (context, state) => _withBackFallback(
          context,
          UserDetailPage(userId: state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/movies',
        builder: (context, state) => _withBackFallback(
          context,
          MovieCatalogPage(
            initialCategory: MovieCategory.fromSlug(
              state.uri.queryParameters['category'],
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/movie/:movieId',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['movieId'] ?? '');
          return id == null
              ? const Scaffold(body: Center(child: Text('Invalid movie ID')))
              : _withBackFallback(context, MovieDetailsPage(movieId: id));
        },
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) =>
            _withBackFallback(context, const MovieSearchPage()),
      ),
      GoRoute(
        path: '/module/:moduleId',
        builder: (context, state) => _withBackFallback(
          context,
          ModulePlaceholderPage(
            moduleId: state.pathParameters['moduleId'] ?? '',
          ),
        ),
      ),
    ],
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final location = state.matchedLocation;
      if (authState.isPasswordRecovery) {
        return location == '/reset-password' ? null : '/reset-password';
      }
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
      // Supabase authenticates the user when they open a recovery link. Keep
      // the reset form reachable for that authenticated recovery session.
      if (authState.user != null && authPage && location != '/reset-password') {
        return '/';
      }
      if (location.startsWith('/module/user-management') &&
          authState.user?.role.toLowerCase() != 'admin') {
        return '/';
      }
      return null;
    },
  );

  ref.onDispose(() {
    router.dispose();
    authRefresh.dispose();
  });

  return router;
});

class _AuthRouterRefreshListenable extends ChangeNotifier {
  void refresh() => notifyListeners();
}

Widget _withBackFallback(BuildContext context, Widget child) =>
    _BackNavigationFallback(router: GoRouter.of(context), child: child);

class _BackNavigationFallback extends StatelessWidget {
  const _BackNavigationFallback({required this.child, required this.router});

  final Widget child;
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    final location = router.state.matchedLocation;
    return PopScope<Object?>(
      canPop: router.canPop() || location == '/',
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && router.state.matchedLocation != '/') {
          router.go('/');
        }
      },
      child: child,
    );
  }
}
