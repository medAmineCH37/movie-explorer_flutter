import 'movie.dart';

/// One page of a paginated movie list.
class MoviePage {
  const MoviePage({
    required this.movies,
    required this.page,
    required this.total,
    required this.pageSize,
  });

  final List<Movie> movies;
  final int page;

  /// Number of movies matching the query, across all pages.
  final int total;
  final int pageSize;

  int get totalPages => total == 0 ? 1 : (total + pageSize - 1) ~/ pageSize;
  bool get hasMore => page < totalPages;

  /// Builds a page from `search_movies` rows (each carries `total_count`).
  factory MoviePage.fromRows(
    List<Map<String, dynamic>> rows, {
    required int page,
    required int pageSize,
  }) {
    return MoviePage(
      movies: rows.map(Movie.fromJson).toList(),
      page: page,
      pageSize: pageSize,
      total: rows.isEmpty ? 0 : (rows.first['total_count'] as num).toInt(),
    );
  }
}
