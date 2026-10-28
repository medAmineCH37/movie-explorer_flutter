
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const modules = <_ModuleItem>[
    _ModuleItem(
      id: 'user-management',
      title: 'User Management',
      description: 'Accounts, authentication and profiles',
      icon: Icons.person_outline,
    ),
    _ModuleItem(
      id: 'movie-management',
      title: 'Movie Management',
      description: 'Explore movie details and metadata',
      icon: Icons.movie_outlined,
    ),
    _ModuleItem(
      id: 'ratings-reviews',
      title: 'Ratings & Reviews',
      description: 'Rate movies and share your opinions',
      icon: Icons.star_outline,
    ),
    _ModuleItem(
      id: 'personal-collection',
      title: 'My Collection',
      description: 'Manage favorites and your watchlist',
      icon: Icons.bookmark_border,
    ),
    _ModuleItem(
      id: 'movie-discovery',
      title: 'Movie Discovery',
      description: 'Search, filter and sort movies',
      icon: Icons.search,
    ),
    _ModuleItem(
      id: 'recommendations-custom-lists',
      title: 'Recommendations & Lists',
      description: 'Discover recommendations and create lists',
      icon: Icons.auto_awesome_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Movie Explorer',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile will be available soon.'),
                ),
              );
            },
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Profile',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.primaryContainer,
                    const Color(0xFF27213C),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.local_movies_outlined,
                    size: 38,
                    color: colors.onPrimaryContainer,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Your next favorite movie starts here.',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: colors.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Discover films, organize your collection and '
                    'share your reviews.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colors.onPrimaryContainer,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Explore the app',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose a section to get started.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            for (final module in modules) ...[
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: colors.primaryContainer,
                    foregroundColor: colors.onPrimaryContainer,
                    child: Icon(module.icon),
                  ),
                  title: Text(
                    module.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(module.description),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/module/${module.id}'),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModuleItem {
  const _ModuleItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
}
