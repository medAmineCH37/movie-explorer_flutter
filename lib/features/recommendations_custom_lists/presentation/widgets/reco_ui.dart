import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/models/tmdb_candidate.dart';

/// Visual tokens of Module 6 (colors come from the shared theme).
class RecoUi {
  RecoUi._();

  static const Color match = Color(0xFF46D369);
  static const Color star = Color(0xFFF5C518);
  static const double radius = 12;
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(horizontal: 16);
}

class MatchBadge extends StatelessWidget {
  const MatchBadge(this.match, {super.key, this.compact = false});

  final int match;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      compact ? '$match%' : '$match% match',
      style: TextStyle(
        color: RecoUi.match,
        fontWeight: FontWeight.w800,
        fontSize: compact ? 11 : 13,
      ),
    );
    if (!compact) return text;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(6),
      ),
      child: text,
    );
  }
}

class RatingLabel extends StatelessWidget {
  const RatingLabel(this.vote, {super.key});

  final double vote;

  @override
  Widget build(BuildContext context) {
    if (vote <= 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, color: RecoUi.star, size: 16),
        const SizedBox(width: 2),
        Text(
          vote.toStringAsFixed(1),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }
}

class PosterImage extends StatelessWidget {
  const PosterImage({
    required this.url,
    super.key,
    this.width,
    this.height,
    this.radius = RecoUi.radius,
    this.fit = BoxFit.cover,
  });

  final String? url;
  final double? width;
  final double? height;
  final double radius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const Icon(Icons.movie_outlined, color: Colors.white24),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null
          ? placeholder
          : CachedNetworkImage(
              imageUrl: url!,
              width: width,
              height: height,
              fit: fit,
              fadeInDuration: const Duration(milliseconds: 250),
              placeholder: (context, url) =>
                  SkeletonBox(width: width, height: height),
              errorWidget: (context, url, error) => placeholder,
            ),
    );
  }
}

/// 2×2 poster collage used as list cover.
class ListCover extends StatelessWidget {
  const ListCover({
    required this.posters,
    super.key,
    this.radius = RecoUi.radius,
  });

  final List<String> posters;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (posters.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.primary.withValues(alpha: 0.55),
                colors.surfaceContainerHighest,
              ],
            ),
          ),
          child: const Center(
            child: Icon(Icons.playlist_add, size: 40, color: Colors.white70),
          ),
        ),
      );
    }
    final urls = [for (final p in posters.take(4)) tmdbImage(p, 'w342')];
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: urls.length < 4
          ? PosterImage(url: urls.first, radius: 0)
          : GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 2 / 3,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [for (final u in urls) PosterImage(url: u, radius: 0)],
            ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.onSeeAll});

  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: text.bodySmall?.copyWith(color: Colors.white60),
                    ),
                  ),
              ],
            ),
          ),
          if (onSeeAll != null)
            TextButton(onPressed: onSeeAll, child: const Text('See all')),
        ],
      ),
    );
  }
}

/// Pulsing placeholder used while content loads.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width, this.height, this.radius = 0});

  final double? width;
  final double? height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.35,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({required this.message, required this.onRetry, super.key});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: Colors.white38,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
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

void showRecoSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
}
