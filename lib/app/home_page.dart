import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movie_explorer/core/widgets/cinea_app_bar.dart';

import '../features/movie_management/data/models/movie.dart';
import '../features/movie_management/data/models/movie_category.dart';
import '../features/movie_management/data/services/tmdb_service.dart';
import '../features/movie_management/presentation/widgets/featured_movie_card.dart';
import '../features/movie_management/presentation/widgets/movie_row_section.dart';
import '../features/movie_management/presentation/widgets/movie_state_views.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.tmdbService});

  final TmdbService? tmdbService;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final TmdbService _tmdbService;

  final Map<MovieCategory, Future<List<Movie>>> _categoryFutures = {};

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
      id: 'subscription-management',
      title: 'Subscription Management',
      description: 'Manage your subscription and billing',
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
  void initState() {
    super.initState();
    _tmdbService = widget.tmdbService ?? TmdbService();
    for (final category in MovieCategory.values) {
      _categoryFutures[category] = _loadCategory(category);
    }
  }

  @override
  void dispose() {
    if (widget.tmdbService == null) _tmdbService.dispose();
    super.dispose();
  }

  /// Rows below the fold may not be built yet, so nothing listens to their
  /// future; `ignore()` keeps a failure from becoming an unhandled error
  /// while FutureBuilder still receives it once the row is shown.
  Future<List<Movie>> _loadCategory(MovieCategory category) {
    return _tmdbService.getMovies(category).then((page) => page.movies)
      ..ignore();
  }

  void _retryCategory(MovieCategory category) {
    setState(() {
      _categoryFutures[category] = _loadCategory(category);
    });
  }

  String _routeFor(String moduleId) {
    return switch (moduleId) {
      'personal-collection' => '/collection',
      'subscription-management' => '/subscription',
      'recommendations-custom-lists' => '/for-you',
      'movie-management' => '/movies',
      'ratings-reviews' => '/my-ratings',
      _ => '/module/$moduleId',
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: CineaAppBar(
        title: 'Movie Explorer',
        actions: [
          IconButton(
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search),
            tooltip: 'Search movies',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'YOUR NEXT MOVIE NIGHT',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Discover something unforgettable.',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),

            // Featured movie: the most popular title right now.
            FutureBuilder<List<Movie>>(
              future: _categoryFutures[MovieCategory.popular],
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SkeletonBox(
                      height: FeaturedMovieCard.height,
                      radius: 24,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return MovieLoadError(
                    message: 'Could not load movies from TMDB.',
                    onRetry: () => _retryCategory(MovieCategory.popular),
                  );
                }

                final movies = snapshot.data ?? const <Movie>[];
                if (movies.isEmpty) {
                  return const MovieEmptyState(
                    message: 'No movies are available right now.',
                  );
                }

                return FeaturedMovieCard(movie: movies.first);
              },
            ),

            const SizedBox(height: 32),

            // One carousel per TMDB catalogue list.
            for (final category in MovieCategory.values) ...[
              MovieRowSection(
                title: category.label,
                icon: category.icon,
                future: _categoryFutures[category]!,
                onRetry: () => _retryCategory(category),
                onSeeAll: () =>
                    context.push('/movies?category=${category.slug}'),
              ),
              const SizedBox(height: 28),
            ],

            const SizedBox(height: 8),

            // Preserve the six collective project modules.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Explore the app',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
              child: Text(
                'Explore all the features of Movie Explorer.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
            for (final module in modules) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
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
                    onTap: () => context.push(_routeFor(module.id)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
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
