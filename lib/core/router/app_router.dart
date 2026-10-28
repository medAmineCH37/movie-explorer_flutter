
import 'package:go_router/go_router.dart';

import '../../app/home_page.dart';
import '../../app/module_placeholder_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/module/:moduleId',
      builder: (context, state) {
        return ModulePlaceholderPage(
          moduleId: state.pathParameters['moduleId'] ?? '',
        );
      },
    ),
  ],
);
