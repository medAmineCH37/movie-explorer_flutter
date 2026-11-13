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
  final String? posterPath;
  final String? backdropPath;
  final double voteAverage;
  final String releaseDate;
  final List<String> genres;
  final int? runtime;
  final int voteCount;
  final String? originalLanguage;

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'] as int,
      title: (json['title'] ?? json['name'] ?? 'Untitled') as String,
      overview: (json['overview'] ?? '') as String,
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      releaseDate:
          (json['release_date'] ?? json['first_air_date'] ?? '') as String,
      genres:
          (json['genres'] as List<dynamic>?)
              ?.map(
                (genre) => genre is Map<String, dynamic>
                    ? genre['name'] as String? ?? ''
                    : '',
              )
              .where((name) => name.isNotEmpty)
              .toList() ??
          const [],
      runtime: (json['runtime'] as num?)?.toInt(),
      voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
      originalLanguage: json['original_language'] as String?,
    );
  }

  /// Four-digit release year, or `null` when TMDB has no release date.
  String? get releaseYear {
    if (releaseDate.length < 4) return null;
    return releaseDate.substring(0, 4);
  }

  String? get posterUrl {
    if (posterPath == null || posterPath!.isEmpty) return null;
    return 'https://image.tmdb.org/t/p/w500$posterPath';
  }

  String? get backdropUrl {
    if (backdropPath == null || backdropPath!.isEmpty) return null;
    return 'https://image.tmdb.org/t/p/w1280$backdropPath';
  }
}
