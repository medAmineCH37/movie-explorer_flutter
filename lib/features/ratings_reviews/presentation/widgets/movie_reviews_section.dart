import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../movie_management/data/models/movie.dart';
import '../../domain/repositories/reviews_repository.dart';
import '../controllers/movie_reviews_controller.dart';
import 'rating_summary_card.dart';
import 'review_actions.dart';
import 'review_card.dart';
import 'review_composer_sheet.dart';
import 'review_dialogs.dart';
import 'star_rating.dart';

/// Community rating, the viewer's rating and review composer, and the
/// review highlights, shown on the movie details page.
class MovieReviewsSection extends StatefulWidget {
  const MovieReviewsSection({
    super.key,
    required this.movie,
    this.repository,
    this.authChanges,
  });

  final Movie movie;
  final ReviewsRepository? repository;

  /// Auth events that trigger a reload; defaults to Supabase auth.
  final Stream<Object?>? authChanges;

  @override
  State<MovieReviewsSection> createState() => _MovieReviewsSectionState();
}

class _MovieReviewsSectionState extends State<MovieReviewsSection> {
  late final MovieReviewsController _controller;
  StreamSubscription<Object?>? _authSubscription;

  Movie get _movie => widget.movie;

  @override
  void initState() {
    super.initState();
    _controller = MovieReviewsController(
      movieId: _movie.id,
      repository: widget.repository,
    )..load();
    _authSubscription = (widget.authChanges ?? _supabaseAuthChanges())?.listen(
      (_) => _controller.load(),
    );
  }

  static Stream<Object?>? _supabaseAuthChanges() {
    try {
      return Supabase.instance.client.auth.onAuthStateChange
          .where(
            (s) =>
                s.event == AuthChangeEvent.signedIn ||
                s.event == AuthChangeEvent.signedOut,
          )
          .map((s) => s.event);
    } catch (_) {
      return null; // Supabase not initialised (tests)
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _signIn() {
    context.push(
      '/login?redirect=${Uri.encodeComponent('/movie/${_movie.id}')}',
    );
  }

  Future<void> _openComposer() async {
    final saved = await showReviewComposer(
      context,
      repository: _controller.repository,
      movieId: _movie.id,
      movieTitle: _movie.title,
      movieYear: _movie.releaseYear,
      myScore: _controller.summary.myScore,
    );
    if (saved == null || !mounted) return;
    showReviewMessage(context, 'Review published.');
    await _controller.reviewChanged();
  }

  Future<void> _removeRating() async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Remove your rating?',
      message: 'Your review, if any, stays published without a score.',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !mounted) return;
    await runReviewAction(
      context,
      _controller.removeRating,
      successMessage: 'Rating removed.',
    );
  }

  Future<void> _openAllReviews() async {
    await context.push('/movie/${_movie.id}/reviews');
    if (mounted) await _controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final c = _controller;
        final theme = Theme.of(context);

        if (c.isLoading && c.summary.count == 0 && c.highlights.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (c.error != null && c.highlights.isEmpty) {
          return Column(
            children: [
              Text(c.error!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: c.load,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          );
        }

        final actions = ReviewCardActions(
          repository: c.repository,
          movieTitle: _movie.title,
          movieYear: _movie.releaseYear,
          isSignedIn: c.isSignedIn,
          isAdmin: c.isAdmin,
          myScore: c.summary.myScore,
          toggleLike: c.toggleLike,
          deleteReview: c.deleteReview,
          report: c.report,
          onChanged: c.reviewChanged,
        );
        final h = c.highlights;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RatingSummaryCard(summary: c.summary),
            const SizedBox(height: 12),
            c.isSignedIn ? _myRatingCard(theme) : _signInCard(theme),
            if (h.mine != null) ...[
              const SizedBox(height: 16),
              actions.card(context, h.mine!, badge: ReviewBadge.mine),
            ],
            if (h.top != null) ...[
              const SizedBox(height: 12),
              actions.card(context, h.top!, badge: ReviewBadge.mostLiked),
            ],
            if (h.latest.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Latest reviews',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              for (final review in h.latest) ...[
                const SizedBox(height: 12),
                actions.card(context, review),
              ],
            ],
            if (h.isEmpty) ...[const SizedBox(height: 16), _EmptyReviews()],
            if (c.reviewCount > 0) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _openAllReviews,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.forum_outlined),
                label: Text(
                  c.reviewCount == 1
                      ? 'See the review'
                      : 'See all ${c.reviewCount} reviews',
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _myRatingCard(ThemeData theme) {
    final c = _controller;
    final myScore = c.summary.myScore;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    myScore == null ? 'Rate this movie' : 'Your rating',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (c.isSavingRating)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (myScore != null)
                  TextButton(
                    onPressed: _removeRating,
                    child: const Text('Remove'),
                  ),
              ],
            ),
            StarRatingInput(
              value: myScore,
              enabled: !c.isSavingRating,
              onChanged: (score) {
                if (score == myScore) return;
                runReviewAction(context, () => c.rate(score));
              },
            ),
            const SizedBox(height: 12),
            if (c.myReview == null)
              FilledButton.icon(
                onPressed: _openComposer,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('Write a review'),
              )
            else
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'You reviewed this movie. Edit or delete it from your '
                      'review card below.',
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _signInCard(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Seen it? Share your opinion.',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text('Sign in to rate this movie and write a review.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _signIn,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.login),
              label: const Text('Sign in to review'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyReviews extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(Icons.chat_bubble_outline, size: 36, color: muted),
          const SizedBox(height: 8),
          Text(
            'No reviews yet. Be the first to share yours!',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted),
          ),
        ],
      ),
    );
  }
}
