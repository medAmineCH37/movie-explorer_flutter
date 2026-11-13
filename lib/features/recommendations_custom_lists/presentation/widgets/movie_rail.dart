import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/recommended_movie.dart';
import '../../domain/models/tmdb_candidate.dart';
import '../../data/list_changes.dart';
import 'add_to_list_sheet.dart';
import 'poster_quick_actions.dart';
import 'reco_ui.dart';

const double _posterWidth = 124;
const double _posterHeight = 186;

/// Opens a movie; on return, recommendations refresh (the user may have
/// rated it or added it to favorites or a list).
Future<void> openMovie(BuildContext context, int movieId) async {
  await context.push('/movie/$movieId');
  ListChanges.instance.notify();
}

/// Horizontal row of posters, Netflix style. Long press: add to a list.
class MovieRail extends StatelessWidget {
  const MovieRail({
    required this.items,
    super.key,
    this.loading = false,
    this.showAddButton = false,
  });

  final List<RecommendedMovie> items;
  final bool loading;

  /// Shows the "+" add-to-list button on each poster.
  final bool showAddButton;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _posterHeight + 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: RecoUi.pagePadding,
        itemCount: loading ? 6 : items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) => loading
            ? const SkeletonBox(
                width: _posterWidth,
                height: _posterHeight,
                radius: RecoUi.radius,
              )
            : MoviePosterCard(item: items[index], showAddButton: showAddButton),
      ),
    );
  }
}

class MoviePosterCard extends StatelessWidget {
  const MoviePosterCard({
    required this.item,
    super.key,
    this.width = _posterWidth,
    this.showAddButton = false,
  });

  final RecommendedMovie item;
  final double width;
  final bool showAddButton;

  @override
  Widget build(BuildContext context) {
    final movie = item.movie;
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(RecoUi.radius),
        onTap: () => openMovie(context, movie.id),
        onLongPress: () => showAddToListSheet(context, movie),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                PosterImage(
                  url: movie.posterUrl,
                  width: width,
                  height: width * 1.5,
                ),
                if (item.match != null)
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: MatchBadge(item.match!, compact: true),
                  ),
                PosterQuickActions(
                  movieId: movie.id,
                  compact: true,
                  showAddButton: showAddButton,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              movie.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            Row(
              children: [
                RatingLabel(movie.voteAverage),
                const Spacer(),
                Text(
                  movie.year,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Top 10 this week": large outlined rank number behind each poster.
class Top10Rail extends StatelessWidget {
  const Top10Rail({
    required this.movies,
    super.key,
    this.loading = false,
    this.showAddButton = false,
  });

  final List<TmdbCandidate> movies;
  final bool loading;
  final bool showAddButton;

  @override
  Widget build(BuildContext context) {
    final top = movies.take(10).toList();
    return SizedBox(
      height: 170,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: loading ? 5 : top.length,
        itemBuilder: (context, index) {
          if (loading) {
            return const Padding(
              padding: EdgeInsets.only(left: 56, right: 8),
              child: SkeletonBox(
                width: 110,
                height: 165,
                radius: RecoUi.radius,
              ),
            );
          }
          final movie = top[index];
          return GestureDetector(
            onTap: () => openMovie(context, movie.id),
            onLongPress: () => showAddToListSheet(context, movie),
            child: SizedBox(
              width: 180,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    bottom: -18,
                    child: _RankNumber(index + 1),
                  ),
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 4,
                    child: SizedBox(
                      width: 110,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          PosterImage(url: movie.posterUrl, width: 110),
                          PosterQuickActions(
                            movieId: movie.id,
                            compact: true,
                            showAddButton: showAddButton,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RankNumber extends StatelessWidget {
  const _RankNumber(this.rank);

  final int rank;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 120,
      fontWeight: FontWeight.w900,
      height: 1,
      letterSpacing: -8,
    );
    return Stack(
      children: [
        Text(
          '$rank',
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = Colors.white70,
          ),
        ),
        Text(
          '$rank',
          style: style.copyWith(
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
        ),
      ],
    );
  }
}
