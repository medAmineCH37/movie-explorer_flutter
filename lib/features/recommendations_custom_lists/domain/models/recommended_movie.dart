import 'tmdb_candidate.dart';

/// A recommended movie with its explanation and compatibility (55–99 %).
class RecommendedMovie {
  const RecommendedMovie({required this.movie, this.reason, this.match});

  final TmdbCandidate movie;

  /// e.g. "Because you added Inception"; null when not relevant.
  final String? reason;

  /// Compatibility percentage (55–99); null for trending or similar movies.
  final int? match;
}

enum RecommendationSource { personal, list, trending }

class RecommendationsResult {
  const RecommendationsResult({
    required this.source,
    required this.results,
    this.topGenres = const [],
  });

  final RecommendationSource source;
  final List<RecommendedMovie> results;
  final List<int> topGenres;
}
