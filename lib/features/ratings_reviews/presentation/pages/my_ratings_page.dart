import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../movie_management/data/models/movie.dart';
import '../../../movie_management/presentation/widgets/movie_poster_image.dart';
import '../../domain/models/review_activity.dart';
import '../../domain/repositories/reviews_repository.dart';
import '../controllers/my_ratings_controller.dart';
import '../relative_time.dart';
import '../widgets/review_composer_sheet.dart';
import '../widgets/review_dialogs.dart';
import '../widgets/star_rating.dart';
import '../../../../core/navigation/app_shell.dart';

/// Everything the signed-in user rated or reviewed.
class MyRatingsPage extends StatefulWidget {
  const MyRatingsPage({super.key, this.repository, this.movieLookup});

  final ReviewsRepository? repository;
  final MovieLookup? movieLookup;

  @override
  State<MyRatingsPage> createState() => _MyRatingsPageState();
}

class _MyRatingsPageState extends State<MyRatingsPage> {
  late final MyRatingsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MyRatingsController(
      repository: widget.repository,
      lookup: widget.movieLookup,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const ShellLeading(),
        leadingWidth: shellLeadingWidth(context),
        title: const Text('My ratings & reviews'),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final c = _controller;

          if (!c.isSignedIn) return const _SignedOut();

          if (c.isLoading && c.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (c.error != null && c.items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(c.error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: c.load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: c.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _StatsRow(stats: c.stats),
                const SizedBox(height: 16),
                if (c.items.isEmpty)
                  const _EmptyActivity()
                else
                  for (final item in c.items) ...[
                    _ActivityCard(
                      key: ValueKey('activity-${item.movieId}'),
                      item: item,
                      movie: c.movies[item.movieId],
                      removed: c.isMovieRemoved(item.movieId),
                      busy: c.busyMovieIds.contains(item.movieId),
                      controller: c,
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final ReviewStats stats;

  @override
  Widget build(BuildContext context) {
    final average = stats.averageScore;
    return Row(
      children: [
        _StatTile(
          icon: Icons.movie_outlined,
          value: '${stats.ratedCount}',
          label: 'Films rated',
        ),
        const SizedBox(width: 10),
        _StatTile(
          icon: Icons.star_rounded,
          value: average == null ? '–' : '${average.toStringAsFixed(1)} ★',
          label: 'My average',
        ),
        const SizedBox(width: 10),
        _StatTile(
          icon: Icons.thumb_up_alt_outlined,
          value: '${stats.likesReceived}',
          label: 'Likes received',
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 22),
              const SizedBox(height: 6),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
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

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    super.key,
    required this.item,
    required this.movie,
    required this.removed,
    required this.busy,
    required this.controller,
  });

  final ReviewActivity item;
  final Movie? movie;
  final bool removed;
  final bool busy;
  final MyRatingsController controller;

  Future<void> _removeRating(BuildContext context) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Remove your rating?',
      message: item.review == null
          ? 'This movie will disappear from this list.'
          : 'Your review stays published without a score.',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !context.mounted) return;
    await runReviewAction(
      context,
      () => controller.removeRating(item.movieId),
      successMessage: 'Rating removed.',
    );
  }

  Future<void> _deleteReview(BuildContext context) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete your review?',
      message: 'The review and its likes will be permanently deleted.',
    );
    if (!confirmed || !context.mounted) return;
    await runReviewAction(
      context,
      () => controller.deleteReview(item),
      successMessage: 'Review deleted.',
    );
  }

  Future<void> _compose(BuildContext context) async {
    final saved = await showReviewComposer(
      context,
      repository: controller.repository,
      movieId: item.movieId,
      movieTitle: movie?.title ?? 'This movie',
      movieYear: movie?.releaseYear,
      myScore: item.score,
      existing: item.review,
    );
    if (saved == null || !context.mounted) return;
    controller.reviewSaved(item.movieId, saved);
    showReviewMessage(
      context,
      item.review == null ? 'Review published.' : 'Review updated.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final review = item.review;
    final title = removed
        ? 'Removed from the catalogue'
        : movie?.title ?? 'Movie #${item.movieId}';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: removed
                  ? null
                  : () => context.push('/movie/${item.movieId}'),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 64,
                      height: 96,
                      child: MoviePosterImage(
                        url: movie?.posterUrl,
                        iconSize: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontStyle: removed ? FontStyle.italic : null,
                          ),
                        ),
                        if (movie?.releaseYear != null)
                          Text(movie!.releaseYear!, style: muted),
                        const SizedBox(height: 4),
                        Text(
                          'Updated ${relativeTime(item.updatedAt)}',
                          style: muted,
                        ),
                      ],
                    ),
                  ),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: removed
                      ? (item.score == null
                            ? Text('Not rated', style: muted)
                            : StarRatingDisplay(
                                value: item.score!.toDouble(),
                                size: 22,
                              ))
                      : StarRatingInput(
                          value: item.score,
                          size: 28,
                          enabled: !busy,
                          onChanged: (score) {
                            if (score == item.score) return;
                            runReviewAction(
                              context,
                              () => controller.rate(item.movieId, score),
                            );
                          },
                        ),
                ),
                if (item.score != null)
                  TextButton(
                    onPressed: busy ? null : () => _removeRating(context),
                    child: const Text('Remove'),
                  ),
              ],
            ),
            if (review != null) ...[
              const Divider(height: 20),
              Row(
                children: [
                  if (review.spoiler)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(
                          Icons.visibility_off_outlined,
                          size: 14,
                          color: theme.colorScheme.error,
                        ),
                        label: const Text('Spoiler'),
                      ),
                    ),
                  Icon(
                    Icons.thumb_up_alt_outlined,
                    size: 14,
                    color: muted?.color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    review.likeCount == 1
                        ? '1 like'
                        : '${review.likeCount} likes',
                    style: muted,
                  ),
                  if (review.edited) Text('  ·  edited', style: muted),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                review.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: busy ? null : () => _compose(context),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                  ),
                  TextButton.icon(
                    onPressed: busy ? null : () => _deleteReview(context),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                  ),
                ],
              ),
            ] else if (!removed && movie != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: busy ? null : () => _compose(context),
                  icon: const Icon(Icons.add_comment_outlined, size: 18),
                  label: const Text('Write a review'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.star_outline_rounded, size: 48, color: muted),
          const SizedBox(height: 12),
          Text(
            "You haven't rated any movie yet.",
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push('/movies'),
            icon: const Icon(Icons.movie_outlined),
            label: const Text('Browse movies'),
          ),
        ],
      ),
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Sign in to see your ratings and reviews.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.push(
                '/login?redirect=${Uri.encodeComponent('/my-ratings')}',
              ),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
