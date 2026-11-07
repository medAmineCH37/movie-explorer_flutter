import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class MovieExplorerApp extends ConsumerWidget {
  const MovieExplorerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'CINEA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.cineaTheme, // Injection de la charte haut de gamme
      routerConfig: goRouter,
    );
  }
}
