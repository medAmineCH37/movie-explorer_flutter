import 'movie.dart';

/// One page of a paginated TMDB movie list.
class MoviePage {
  const MoviePage({
    required this.movies,
    required this.page,
    required this.totalPages,
  });

  /// TMDB refuses list pages above 500.
  static const int maxTmdbPage = 500;

  final List<Movie> movies;
  final int page;
  final int totalPages;

  bool get hasMore => page < totalPages && page < maxTmdbPage;

  factory MoviePage.fromJson(Map<String, dynamic> json) {
    final results = json['results'] as List<dynamic>? ?? const [];
    return MoviePage(
      movies: results
          .map((item) => Movie.fromJson(item as Map<String, dynamic>))
          .toList(),
      page: (json['page'] as num?)?.toInt() ?? 1,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 1,
    );
  }
}
