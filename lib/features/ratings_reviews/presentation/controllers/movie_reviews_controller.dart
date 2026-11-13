import 'package:flutter/foundation.dart';

import '../../data/repositories/reviews_repository_impl.dart';
import '../../domain/models/rating_summary.dart';
import '../../domain/models/review.dart';
import '../../domain/models/review_sort.dart';
import '../../domain/repositories/reviews_repository.dart';

/// State of the community section on the movie details page.
///
/// Mutations throw [ReviewException]; the UI shows the message.
class MovieReviewsController extends ChangeNotifier {
  MovieReviewsController({required this.movieId, ReviewsRepository? repository})
    : _repository = repository ?? ReviewsRepositoryImpl(),
      summary = RatingSummary.empty(movieId);

  final int movieId;
  final ReviewsRepository _repository;

  /// Reviews fetched to fill "latest" after excluding pinned/top ones.
  static const int _recentFetchCount = 5;

  RatingSummary summary;
  ReviewHighlights highlights = const ReviewHighlights();
  bool isAdmin = false;

  bool isLoading = false;
  String? error;
  bool isSavingRating = false;
  bool _disposed = false;

  bool get isSignedIn => _repository.currentUserId != null;
  Review? get myReview => highlights.mine;
  int get reviewCount => summary.reviewCount;
  ReviewsRepository get repository => _repository;

  Future<void> load() async {
    isLoading = true;
    error = null;
    _notify();

    try {
      final results = await Future.wait<Object?>([
        _repository.getRatingSummary(movieId),
        _repository.getReviews(movieId, pageSize: _recentFetchCount),
        _repository.getReviews(movieId, sort: ReviewSort.likes, pageSize: 1),
        _repository.getMyReview(movieId),
        _repository.isAdmin(),
      ]);
      summary = results[0] as RatingSummary;
      final recent = results[1] as ReviewPage;
      final mostLiked = results[2] as ReviewPage;
      highlights = ReviewHighlights.compose(
        mine: results[3] as Review?,
        mostLiked: mostLiked.reviews.isEmpty ? null : mostLiked.reviews.first,
        recent: recent.reviews,
      );
      isAdmin = results[4] as bool;
    } on ReviewException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Could not load reviews.';
    } finally {
      isLoading = false;
      _notify();
    }
  }

  Future<void> rate(int score) async {
    isSavingRating = true;
    _notify();
    try {
      summary = await _repository.rateMovie(movieId, score);
      // The author's score is shown on their review card.
      await _refreshMyReview();
    } finally {
      isSavingRating = false;
      _notify();
    }
  }

  Future<void> removeRating() async {
    isSavingRating = true;
    _notify();
    try {
      summary = await _repository.removeRating(movieId);
      await _refreshMyReview();
    } finally {
      isSavingRating = false;
      _notify();
    }
  }

  /// Reloads everything after a review was created, edited or deleted.
  Future<void> reviewChanged() => load();

  Future<void> deleteReview(Review review) async {
    await _repository.deleteReview(review.id);
    await load();
  }

  Future<void> toggleLike(Review review) async {
    final updated = await _repository.toggleLike(review);
    highlights = ReviewHighlights(
      mine: highlights.mine,
      top: highlights.top?.id == updated.id ? updated : highlights.top,
      latest: [
        for (final r in highlights.latest) r.id == updated.id ? updated : r,
      ],
    );
    _notify();
  }

  Future<void> report(Review review, String reason) =>
      _repository.reportReview(review.id, reason);

  Future<void> _refreshMyReview() async {
    final mine = highlights.mine;
    if (mine == null) return;
    highlights = ReviewHighlights(
      mine: await _repository.getMyReview(movieId),
      top: highlights.top,
      latest: highlights.latest,
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
