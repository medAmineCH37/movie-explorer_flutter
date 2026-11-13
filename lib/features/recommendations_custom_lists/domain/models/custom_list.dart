import 'tmdb_candidate.dart';

class CustomList {
  const CustomList({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description = '',
    this.isPublic = false,
    this.movieCount = 0,
    this.previewPosters = const [],
    this.movies = const [],
    this.ownerName,
    this.updatedAt,
  });

  final int id;
  final String ownerId;
  final String name;
  final String description;
  final bool isPublic;
  final int movieCount;
  final List<String> previewPosters;

  /// Only filled when the full list is loaded (detail page).
  final List<ListMovie> movies;
  final String? ownerName;
  final DateTime? updatedAt;

  factory CustomList.fromJson(Map<String, dynamic> json) {
    final movies =
        (json['custom_list_movies'] as List<dynamic>?)
            ?.map((m) => ListMovie.fromJson(m as Map<String, dynamic>))
            .toList() ??
        const <ListMovie>[];
    return CustomList(
      id: (json['id'] as num).toInt(),
      ownerId: json['user_id'] as String,
      name: json['name'] as String,
      description: (json['description'] ?? '') as String,
      isPublic: (json['is_public'] ?? false) as bool,
      movieCount: (json['movie_count'] as num?)?.toInt() ?? movies.length,
      previewPosters:
          (json['preview_posters'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          _previews(movies),
      movies: movies,
      ownerName: json['owner_name'] as String?,
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '') as String),
    );
  }

  CustomList copyWith({
    String? name,
    String? description,
    bool? isPublic,
    List<ListMovie>? movies,
    String? ownerName,
    int? movieCount,
  }) {
    return CustomList(
      id: id,
      ownerId: ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      isPublic: isPublic ?? this.isPublic,
      movieCount: movieCount ?? movies?.length ?? this.movieCount,
      previewPosters: movies != null ? _previews(movies) : previewPosters,
      movies: movies ?? this.movies,
      ownerName: ownerName ?? this.ownerName,
      updatedAt: updatedAt,
    );
  }

  static List<String> _previews(List<ListMovie> movies) =>
      movies.map((m) => m.posterPath).whereType<String>().take(4).toList();
}

/// Movie stored in a list (TMDB data denormalized at insertion time).
class ListMovie {
  const ListMovie({
    required this.movieId,
    required this.title,
    this.posterPath,
    this.genreIds = const [],
    this.voteAverage = 0,
    this.addedAt,
  });

  final int movieId;
  final String title;
  final String? posterPath;
  final List<int> genreIds;
  final double voteAverage;
  final DateTime? addedAt;

  factory ListMovie.fromJson(Map<String, dynamic> json) => ListMovie(
    movieId: (json['tmdb_movie_id'] as num).toInt(),
    title: (json['title'] ?? '') as String,
    posterPath: json['poster_path'] as String?,
    genreIds:
        (json['genre_ids'] as List<dynamic>?)
            ?.map((g) => (g as num).toInt())
            .toList() ??
        const [],
    voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0,
    addedAt: DateTime.tryParse((json['added_at'] ?? '') as String),
  );

  factory ListMovie.fromCandidate(TmdbCandidate m) => ListMovie(
    movieId: m.id,
    title: m.title,
    posterPath: m.posterPath,
    genreIds: m.genreIds,
    voteAverage: m.voteAverage,
    addedAt: DateTime.now(),
  );

  Map<String, dynamic> toInsertJson(int listId) => {
    'list_id': listId,
    'tmdb_movie_id': movieId,
    'title': title,
    'poster_path': posterPath,
    'genre_ids': genreIds,
    'vote_average': voteAverage,
  };

  String? get posterUrl => tmdbImage(posterPath, 'w342');
}
