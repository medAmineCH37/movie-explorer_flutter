/// Movie as returned by TMDB list endpoints (trending, recommendations, discover).
/// Pure Dart: keeps `genre_ids`, which the shared `Movie` model does not expose.
class TmdbCandidate {
  const TmdbCandidate({
    required this.id,
    required this.title,
    this.overview = '',
    this.posterPath,
    this.backdropPath,
    this.voteAverage = 0,
    this.releaseDate = '',
    this.genreIds = const [],
  });

  final int id;
  final String title;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final double voteAverage;
  final String releaseDate;
  final List<int> genreIds;

  factory TmdbCandidate.fromJson(Map<String, dynamic> json) {
    final ids =
        (json['genre_ids'] as List<dynamic>?)?.whereType<int>().toList() ??
        (json['genres'] as List<dynamic>?)
            ?.map((g) => g is Map<String, dynamic> ? g['id'] : null)
            .whereType<int>()
            .toList() ??
        const <int>[];
    return TmdbCandidate(
      id: json['id'] as int,
      title: (json['title'] ?? json['name'] ?? 'Untitled') as String,
      overview: (json['overview'] ?? '') as String,
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0,
      releaseDate: (json['release_date'] ?? '') as String,
      genreIds: ids,
    );
  }

  String? get posterUrl => tmdbImage(posterPath, 'w500');
  String? get backdropUrl => tmdbImage(backdropPath, 'w1280');
  String get year => releaseDate.length >= 4 ? releaseDate.substring(0, 4) : '';
}

String? tmdbImage(String? path, String size) => path == null || path.isEmpty
    ? null
    : 'https://image.tmdb.org/t/p/$size$path';
