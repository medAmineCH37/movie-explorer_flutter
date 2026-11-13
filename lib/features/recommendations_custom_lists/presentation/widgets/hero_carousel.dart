import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/models/recommended_movie.dart';
import 'add_to_list_sheet.dart';
import 'movie_rail.dart';
import 'reco_ui.dart';

/// Full-width auto-playing banner with the best recommendations.
class HeroCarousel extends StatefulWidget {
  const HeroCarousel({required this.items, super.key, this.loading = false});

  final List<RecommendedMovie> items;
  final bool loading;

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      final count = widget.items.length;
      if (!mounted || count < 2 || !_controller.hasClients) return;
      _controller.animateToPage(
        (_index + 1) % count,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.62;
    if (widget.loading || widget.items.isEmpty) {
      return SkeletonBox(height: height, width: double.infinity);
    }
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => _HeroSlide(item: widget.items[i]),
          ),
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.items.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _index ? Colors.white : Colors.white38,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSlide extends StatelessWidget {
  const _HeroSlide({required this.item});

  final RecommendedMovie item;

  @override
  Widget build(BuildContext context) {
    final movie = item.movie;
    final background = Theme.of(context).scaffoldBackgroundColor;
    return GestureDetector(
      onTap: () => openMovie(context, movie.id),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PosterImage(url: movie.backdropUrl ?? movie.posterUrl, radius: 0),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.35, 0.75, 1],
                colors: [
                  background.withValues(alpha: 0.55),
                  Colors.transparent,
                  background.withValues(alpha: 0.85),
                  background,
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.reason != null)
                  Text(
                    item.reason!.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  movie.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w900, height: 1.05),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (item.match != null) MatchBadge(item.match!),
                    RatingLabel(movie.voteAverage),
                    if (movie.year.isNotEmpty)
                      Text(
                        movie.year,
                        style: const TextStyle(color: Colors.white70),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  movie.overview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, height: 1.35),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => openMovie(context, movie.id),
                        icon: const Icon(Icons.info_outline),
                        label: const Text(
                          'Details',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => showAddToListSheet(context, movie),
                        icon: const Icon(Icons.add),
                        label: const Text('My lists'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
