import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/movie.dart';
import '../../../recommendations_custom_lists/presentation/widgets/poster_quick_actions.dart';
import 'movie_poster_image.dart';

/// Poster card used by the catalogue rows and grids.
///
/// Shows the poster with the TMDB score, then the title and release year.
/// Tapping opens `/movie/:id` unless [onTap] is given.
class MovieCard extends StatelessWidget {
  const MovieCard({super.key, required this.movie, this.width, this.onTap});

  final Movie movie;
  final double? width;
  final VoidCallback? onTap;

  static const Color starColor = Color(0xFFFFC857);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final year = movie.releaseYear;

    return SizedBox(
      width: width,
      child: Semantics(
        button: true,
        label: [movie.title, ?year].join(', '),
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap ?? () => context.push('/movie/${movie.id}'),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MoviePosterImage(url: movie.posterUrl),
                      if (movie.voteAverage > 0)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: _ScoreBadge(score: movie.voteAverage),
                        ),
                      PosterQuickActions(movieId: movie.id),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                movie.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                year ?? 'Release date TBA',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xCC101014),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 14, color: MovieCard.starColor),
          const SizedBox(width: 3),
          Text(
            score.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
