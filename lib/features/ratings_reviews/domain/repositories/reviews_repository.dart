import '../models/rating_summary.dart';
import '../models/review.dart';
import '../models/review_activity.dart';
import '../models/review_sort.dart';

/// Thrown with a message that can be shown to the user as is.
class ReviewException implements Exception {
  const ReviewException(this.message, {this.requiresSignIn = false});

  final String message;
  final bool requiresSignIn;

  @override
  String toString() => message;
}

abstract class ReviewsRepository {
  /// Id of the signed-in user, or `null` when signed out.
  String? get currentUserId;

  Future<bool> isAdmin();

  Future<RatingSummary> getRatingSummary(int movieId);

  /// Creates or replaces the user's rating; returns the new summary.
  Future<RatingSummary> rateMovie(int movieId, int score);

  /// Deletes the user's rating; returns the new summary.
  Future<RatingSummary> removeRating(int movieId);

  Future<ReviewPage> getReviews(
    int movieId, {
    ReviewSort sort = ReviewSort.recent,
    int page = 1,
    int pageSize = 10,
  });

  /// The signed-in user's review of [movieId], if any.
  Future<Review?> getMyReview(int movieId);

  Future<Review> createReview(
    int movieId, {
    required String content,
    required bool spoiler,
  });

  Future<Review> updateReview(
    int reviewId, {
    required String content,
    required bool spoiler,
  });

  Future<void> deleteReview(int reviewId);

  /// Likes or unlikes [review]; returns the review with updated counts.
  Future<Review> toggleLike(Review review);

  Future<void> reportReview(int reviewId, String reason);

  /// Everything the signed-in user rated or reviewed.
  Future<List<ReviewActivity>> getMyActivity();
}
