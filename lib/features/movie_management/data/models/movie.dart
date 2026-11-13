/// A catalogue movie (row of `public.movies` or of `search_movies`).
class Movie {
  const Movie({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.voteAverage,
    required this.releaseDate,
    this.genres = const [],
    this.runtime,
    this.voteCount = 0,
    this.originalLanguage,
  });

  final int id;
  final String title;
  final String overview;

  /// Full image URL (or a legacy TMDB image path such as `/abc.jpg`).
  final String? posterPath;
  final String? backdropPath;
  final double voteAverage;

  /// `YYYY-MM-DD`, or empty when unknown.
  final String releaseDate;
  final List<String> genres;
  final int? runtime;
  final int voteCount;
  final String? originalLanguage;

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? 'Untitled',
      overview: json['overview'] as String? ?? '',
      posterPath: (json['poster_url'] ?? json['poster_path']) as String?,
      backdropPath: (json['backdrop_url'] ?? json['backdrop_path']) as String?,
      voteAverage: _toDouble(json['vote_average']),
      releaseDate: json['release_date'] as String? ?? '',
      genres: parseGenreNames(json['genres'] ?? json['movie_genres']),
      runtime: (json['runtime'] as num?)?.toInt(),
      voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
      originalLanguage: json['original_language'] as String?,
    );
  }

  /// Accepts `['Drama', …]`, `[{name: 'Drama'}, …]` or the embedded
  /// `movie_genres(genres(name))` shape.
  static List<String> parseGenreNames(Object? value) {
    if (value is! List) return const [];
    final names = <String>[];
    for (final item in value) {
      final name = switch (item) {
        String s => s,
        {'genres': {'name': final String n}} => n,
        {'name': final String n} => n,
        _ => null,
      };
      if (name != null && name.isNotEmpty) names.add(name);
    }
    return names;
  }

  static double _toDouble(Object? value) => switch (value) {
    num n => n.toDouble(),
    String s => double.tryParse(s) ?? 0,
    _ => 0,
  };

  /// Four-digit release year, or `null` when the release date is unknown.
  String? get releaseYear {
    if (releaseDate.length < 4) return null;
    return releaseDate.substring(0, 4);
  }

  String? get posterUrl => _imageUrl(posterPath, 'w500');

  String? get backdropUrl => _imageUrl(backdropPath, 'w1280');

  static String? _imageUrl(String? value, String size) {
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('https://') || value.startsWith('http://')) {
      return value;
    }
    return 'https://image.tmdb.org/t/p/$size$value';
  }
}
