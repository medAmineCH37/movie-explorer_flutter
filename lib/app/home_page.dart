import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movie_explorer/core/branding.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CineaAppBar(
        title: appName,
        actions: [
          IconButton(
            onPressed: () => context.go('/search'),
            icon: const Icon(Icons.search),
            tooltip: 'Search movies',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            const SizedBox(height: 12),

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
          ],
        ),
      ),
    );
  }
}
