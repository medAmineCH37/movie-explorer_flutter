import 'package:flutter/material.dart';

import '../../data/models/movie.dart';
import 'movie_card.dart';
import 'movie_state_views.dart';

/// Titled horizontal carousel of [MovieCard]s with loading, error and
/// empty states.
class MovieRowSection extends StatelessWidget {
  const MovieRowSection({
    super.key,
    required this.title,
    required this.icon,
    required this.future,
    required this.onRetry,
    this.onSeeAll,
  });

  final String title;
  final IconData icon;
  final Future<List<Movie>> future;
  final VoidCallback onRetry;
  final VoidCallback? onSeeAll;

  static const double _rowHeight = 250;
  static const double _cardWidth = 140;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 6),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (onSeeAll != null)
                TextButton(onPressed: onSeeAll, child: const Text('See all')),
            ],
          ),
        ),
        FutureBuilder<List<Movie>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return SizedBox(
                height: _rowHeight,
                child: ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: 4,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (_, _) => const SkeletonBox(width: _cardWidth),
                ),
              );
            }

            if (snapshot.hasError) {
              return MovieLoadError(
                message: '$title could not be loaded.',
                onRetry: onRetry,
              );
            }

            final movies = snapshot.data ?? const <Movie>[];
            if (movies.isEmpty) {
              return const MovieEmptyState(
                message: 'No movies are available right now.',
              );
            }

            return SizedBox(
              height: _rowHeight,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: movies.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, index) =>
                    MovieCard(movie: movies[index], width: _cardWidth),
              ),
            );
          },
        ),
      ],
    );
  }
}
