import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../data/services/tmdb_service.dart';
import '../../../personal_collection/presentation/widgets/movie_collection_actions.dart';

class MovieDetailsPage extends StatefulWidget {
  const MovieDetailsPage({super.key, required this.movieId});

  final int movieId;

  @override
  State<MovieDetailsPage> createState() => _MovieDetailsPageState();
}

class _MovieDetailsPageState extends State<MovieDetailsPage> {
  late final TmdbService _tmdbService;
  late Future<Map<String, dynamic>> _movieFuture;

  @override
  void initState() {
    super.initState();
    _tmdbService = TmdbService();
    _movieFuture = _tmdbService.getMovieDetails(widget.movieId);
  }

  @override
  void dispose() {
    _tmdbService.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _movieFuture = _tmdbService.getMovieDetails(widget.movieId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _movieFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorView(onRetry: _retry);
          }

          final movie = snapshot.data;

          if (movie == null) {
            return _ErrorView(onRetry: _retry);
          }

          final title = movie['title'] as String? ?? 'Unknown movie';
          final overview = movie['overview'] as String? ?? '';
          final posterPath = movie['poster_path'] as String?;
          final backdropPath = movie['backdrop_path'] as String?;
          final releaseDate = movie['release_date'] as String? ?? '';
          final voteAverage =
              (movie['vote_average'] as num?)?.toDouble() ?? 0.0;
          final runtime = movie['runtime'] as int?;
          final genres =
              (movie['genres'] as List<dynamic>?)
                  ?.map((genre) => genre['name'] as String)
                  .toList() ??
              <String>[];

          final backdropUrl = backdropPath != null
              ? 'https://image.tmdb.org/t/p/w1280$backdropPath'
              : null;
          final posterUrl = posterPath != null
              ? 'https://image.tmdb.org/t/p/w500$posterPath'
              : null;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: const Color(0xFF101014),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (backdropUrl != null)
                        CachedNetworkImage(
                          imageUrl: backdropUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => const SizedBox.shrink(),
                        )
                      else
                        const ColoredBox(color: Color(0xFF252530)),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xFF101014)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (posterUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: posterUrl,
                                width: 115,
                                height: 170,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => const SizedBox(
                                  width: 115,
                                  height: 170,
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                errorWidget: (_, _, _) => const SizedBox(
                                  width: 115,
                                  height: 170,
                                  child: Icon(Icons.movie_outlined, size: 40),
                                ),
                              ),
                            ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      voteAverage.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Text(' / 10'),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if (releaseDate.isNotEmpty)
                                  Text('Release date: $releaseDate'),
                                if (runtime != null && runtime > 0) ...[
                                  const SizedBox(height: 8),
                                  Text('$runtime minutes'),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (genres.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: genres
                              .map(
                                (genre) => Chip(
                                  label: Text(genre),
                                  backgroundColor: const Color(0xFF292433),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 28),
                      Text(
                        'Overview',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        overview.isNotEmpty
                            ? overview
                            : 'No overview available for this movie.',
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(height: 1.6, color: Colors.white70),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'My Collection',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      MovieCollectionActions(movieId: widget.movieId),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Could not load movie details.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
