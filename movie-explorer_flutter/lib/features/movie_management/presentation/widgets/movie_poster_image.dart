import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Network poster/backdrop with a themed placeholder and fallback.
class MoviePosterImage extends StatelessWidget {
  const MoviePosterImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.iconSize = 36,
  });

  final String? url;
  final BoxFit fit;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    if (url == null) return _Fallback(iconSize: iconSize);

    return CachedNetworkImage(
      imageUrl: url!,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 250),
      placeholder: (_, _) => _Fallback(iconSize: iconSize, loading: true),
      errorWidget: (_, _, _) => _Fallback(iconSize: iconSize),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.iconSize, this.loading = false});

  final double iconSize;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      color: colors.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        loading ? Icons.image_outlined : Icons.movie_outlined,
        size: iconSize,
        color: colors.onSurfaceVariant,
      ),
    );
  }
}
