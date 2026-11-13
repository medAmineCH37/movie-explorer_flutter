
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ModulePlaceholderPage extends StatelessWidget {
  const ModulePlaceholderPage({
    required this.moduleId,
    super.key,
  });

  final String moduleId;

  String get _title {
    return switch (moduleId) {
      'user-management' => 'User Management',
      'movie-management' => 'Movie Management',
      'ratings-reviews' => 'Ratings & Reviews',
      'personal-collection' => 'My Collection',
      'movie-discovery' => 'Movie Discovery',
      'recommendations-custom-lists' => 'Recommendations & Lists',
      _ => 'Unknown Module',
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        leading: IconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to home',
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.construction_outlined,
                size: 64,
                color: colors.primary,
              ),
              const SizedBox(height: 20),
              Text(
                _title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'This module is part of the shared project foundation. '
                'Its features will be implemented by the team.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Back to home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
