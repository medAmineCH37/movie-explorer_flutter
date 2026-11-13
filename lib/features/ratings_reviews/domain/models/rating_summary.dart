/// Community rating of one movie (from `get_movie_rating_summary`).
class RatingSummary {
  const RatingSummary({
    required this.movieId,
    required this.average,
    required this.count,
    required this.distribution,
    required this.myScore,
    required this.reviewCount,
  });

  const RatingSummary.empty(this.movieId)
    : average = 0,
      count = 0,
      distribution = const [0, 0, 0, 0, 0],
      myScore = null,
      reviewCount = 0;

  final int movieId;

  /// Average score rounded to one decimal; 0 when nobody rated the movie.
  final double average;
  final int count;

  /// Votes per score: index 0 is 1 star, index 4 is 5 stars.
  final List<int> distribution;
  final int? myScore;
  final int reviewCount;

  bool get hasRatings => count > 0;

  int votesFor(int score) => distribution[score - 1];

  /// Bar length for [score], relative to the most voted score (0–1).
  double barFraction(int score) {
    final top = distribution.fold<int>(0, (a, b) => a > b ? a : b);
    return top == 0 ? 0 : votesFor(score) / top;
  }

  factory RatingSummary.fromJson(Map<String, dynamic> json) {
    final distribution = (json['distribution'] as List<dynamic>? ?? const [])
        .map((v) => (v as num).toInt())
        .toList();
    return RatingSummary(
      movieId: (json['tmdb_movie_id'] as num).toInt(),
      average: (json['average'] as num?)?.toDouble() ?? 0,
      count: (json['count'] as num?)?.toInt() ?? 0,
      distribution: distribution.length == 5
          ? distribution
          : const [0, 0, 0, 0, 0],
      myScore: (json['my_score'] as num?)?.toInt(),
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
    );
  }
}
