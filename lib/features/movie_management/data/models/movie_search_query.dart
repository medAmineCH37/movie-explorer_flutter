import 'movie_category.dart';

enum MovieSort {
  popularity('popularity', 'Most popular'),
  rating('rating', 'Highest rated'),
  newest('newest', 'Newest'),
  oldest('oldest', 'Oldest'),
  title('title', 'Title A–Z');

  const MovieSort(this.value, this.label);

  /// Value understood by the `search_movies` database function.
  final String value;
  final String label;
}

/// Discovery filters; also used for catalogue lists via [category].
class MovieSearchQuery {
  const MovieSearchQuery({
    this.text = '',
    this.genreIds = const {},
    this.yearFrom,
    this.yearTo,
    this.minRating,
    this.language,
    this.category,
    this.sort,
  });

  final String text;
  final Set<int> genreIds;
  final int? yearFrom;
  final int? yearTo;

  /// Minimum source rating (0–10).
  final double? minRating;
  final String? language;
  final MovieCategory? category;

  /// `null` lets the category pick its natural order.
  final MovieSort? sort;

  /// Number of active filters (search text and sort excluded).
  int get activeFilterCount =>
      (genreIds.isEmpty ? 0 : 1) +
      (yearFrom != null || yearTo != null ? 1 : 0) +
      (minRating != null ? 1 : 0) +
      (language != null ? 1 : 0);

  MovieSearchQuery copyWith({
    String? text,
    Set<int>? genreIds,
    int? Function()? yearFrom,
    int? Function()? yearTo,
    double? Function()? minRating,
    String? Function()? language,
    MovieSort? Function()? sort,
  }) {
    return MovieSearchQuery(
      text: text ?? this.text,
      genreIds: genreIds ?? this.genreIds,
      yearFrom: yearFrom != null ? yearFrom() : this.yearFrom,
      yearTo: yearTo != null ? yearTo() : this.yearTo,
      minRating: minRating != null ? minRating() : this.minRating,
      language: language != null ? language() : this.language,
      category: category,
      sort: sort != null ? sort() : this.sort,
    );
  }

  MovieSearchQuery clearFilters() =>
      MovieSearchQuery(text: text, category: category, sort: sort);

  Map<String, dynamic> toParams({required int page, required int pageSize}) {
    final trimmed = text.trim();
    return {
      'p_query': trimmed.isEmpty ? null : trimmed,
      'p_genre_ids': genreIds.isEmpty ? null : genreIds.toList(),
      'p_year_from': yearFrom,
      'p_year_to': yearTo,
      'p_min_rating': minRating,
      'p_language': language,
      'p_category': category?.slug,
      'p_sort': sort?.value,
      'p_page': page,
      'p_page_size': pageSize,
    };
  }
}
