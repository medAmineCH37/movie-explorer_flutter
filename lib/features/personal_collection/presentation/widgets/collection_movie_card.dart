
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../movie_management/data/models/movie.dart';

class CollectionMovieCard extends StatelessWidget {
  const CollectionMovieCard({
    super.key,
    required this.movie,
    required this.onRemove,
    this.onTap,
  });

  final Movie movie;
  final VoidCallback onRemove;
  final VoidCallback? onTap;

  String get _releaseYear {
    if (movie.releaseDate.length >= 4) {
      return movie.releaseDate.substring(0, 4);
    }
    return 'Unknown year';
  }

  @override
  Widget build(BuildContext context) {
    final posterUrl = movie.posterUrl;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: posterUrl != null
                      ? CachedNetworkImage(
                          imageUrl: posterUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => _posterPlaceholder(),
                          errorWidget: (context, url, error) =>
                              _posterPlaceholder(),
                        )
                      : _posterPlaceholder(),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: onRemove,
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                      tooltip: 'Remove from collection',
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            movie.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                color: Colors.amber,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                movie.voteAverage.toStringAsFixed(1),
                style: const TextStyle(fontSize: 12),
              ),
              const Spacer(),
              Text(
                _releaseYear,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _posterPlaceholder() {
    return Container(
      color: const Color(0xFF1B1B23),
      alignment: Alignment.center,
      child: const Icon(
        Icons.movie_outlined,
        size: 42,
        color: Colors.white38,
      ),
    );
  }
}
