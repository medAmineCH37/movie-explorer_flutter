import 'review.dart';

/// A movie the user rated and/or reviewed (My ratings & reviews screen).
class ReviewActivity {
  const ReviewActivity({
    required this.movieId,
    this.score,
    this.review,
    required this.updatedAt,
  });

  final int movieId;
  final int? score;
  final Review? review;

  /// Latest change to the rating or the review.
  final DateTime updatedAt;

  /// Merges ratings (`movieId → (score, updatedAt)`) and reviews per movie,
  /// most recently changed first.
  static List<ReviewActivity> merge({
    required Map<int, (int, DateTime)> ratings,
    required List<Review> reviews,
  }) {
    final reviewsByMovie = {for (final r in reviews) r.movieId: r};
    final movieIds = {...ratings.keys, ...reviewsByMovie.keys};

    final items = [
      for (final id in movieIds)
        () {
          final rating = ratings[id];
          final review = reviewsByMovie[id];
          final dates = [?rating?.$2, ?review?.updatedAt];
          return ReviewActivity(
            movieId: id,
            score: rating?.$1,
            review: review,
            updatedAt: dates.reduce((a, b) => a.isAfter(b) ? a : b),
          );
        }(),
    ];
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }
}

class ReviewStats {
  const ReviewStats({
    required this.ratedCount,
    required this.averageScore,
    required this.likesReceived,
  });

  final int ratedCount;

  /// `null` when no movie is rated.
  final double? averageScore;
  final int likesReceived;

  factory ReviewStats.from(List<ReviewActivity> items) {
    final scores = [for (final i in items) ?i.score];
    final likes = items.fold<int>(
      0,
      (sum, i) => sum + (i.review?.likeCount ?? 0),
    );
    return ReviewStats(
      ratedCount: scores.length,
      averageScore: scores.isEmpty
          ? null
          : scores.reduce((a, b) => a + b) / scores.length,
      likesReceived: likes,
    );
  }
}
