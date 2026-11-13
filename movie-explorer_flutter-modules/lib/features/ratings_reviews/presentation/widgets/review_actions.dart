import 'package:flutter/material.dart';

import '../../domain/models/review.dart';
import '../../domain/repositories/reviews_repository.dart';
import 'review_card.dart';
import 'review_composer_sheet.dart';
import 'review_dialogs.dart';

/// Builds [ReviewCard]s wired to the shared review actions (like, edit,
/// delete, report) so the movie page and the full list behave the same.
class ReviewCardActions {
  const ReviewCardActions({
    required this.repository,
    required this.movieTitle,
    required this.movieYear,
    required this.isSignedIn,
    required this.isAdmin,
    required this.myScore,
    required this.toggleLike,
    required this.deleteReview,
    required this.report,
    required this.onChanged,
  });

  final ReviewsRepository repository;
  final String movieTitle;
  final String? movieYear;
  final bool isSignedIn;
  final bool isAdmin;
  final int? myScore;
  final Future<void> Function(Review) toggleLike;
  final Future<void> Function(Review) deleteReview;
  final Future<void> Function(Review, String) report;

  /// Called after a review was edited (to reload the list).
  final Future<void> Function() onChanged;

  Widget card(BuildContext context, Review review, {ReviewBadge? badge}) {
    return ReviewCard(
      key: ValueKey('review-${review.id}'),
      review: review,
      isSignedIn: isSignedIn,
      isAdmin: isAdmin,
      badge: badge,
      onLike: () => _like(context, review),
      onEdit: () => _edit(context, review),
      onDelete: () => _delete(context, review),
      onReport: () => _report(context, review),
    );
  }

  Future<void> _like(BuildContext context, Review review) async {
    if (!isSignedIn) {
      showReviewMessage(
        context,
        'Sign in to like reviews.',
        requiresSignIn: true,
      );
      return;
    }
    await runReviewAction(context, () => toggleLike(review));
  }

  Future<void> _edit(BuildContext context, Review review) async {
    final saved = await showReviewComposer(
      context,
      repository: repository,
      movieId: review.movieId,
      movieTitle: movieTitle,
      movieYear: movieYear,
      myScore: myScore,
      existing: review,
    );
    if (saved == null || !context.mounted) return;
    showReviewMessage(context, 'Review updated.');
    await onChanged();
  }

  Future<void> _delete(BuildContext context, Review review) async {
    final confirmed = await confirmDestructive(
      context,
      title: review.isMine ? 'Delete your review?' : 'Delete this review?',
      message: 'The review and its likes will be permanently deleted.',
    );
    if (!confirmed || !context.mounted) return;
    await runReviewAction(
      context,
      () => deleteReview(review),
      successMessage: 'Review deleted.',
    );
  }

  Future<void> _report(BuildContext context, Review review) async {
    final sent = await showReportSheet(
      context,
      onSubmit: (reason) => report(review, reason),
    );
    if (sent && context.mounted) {
      showReviewMessage(context, 'Thanks, the review was reported.');
    }
  }
}
