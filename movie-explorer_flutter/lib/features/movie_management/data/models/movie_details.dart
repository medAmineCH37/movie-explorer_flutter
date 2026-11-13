import 'movie.dart';

/// Full movie record from `/movie/{id}?append_to_response=credits,videos`.
class MovieDetails {
  const MovieDetails({
    required this.movie,
    this.tagline = '',
    this.status = '',
    this.languageName,
    this.cast = const [],
    this.directors = const [],
    this.trailer,
  });

  final Movie movie;
  final String tagline;
  final String status;

  /// English name of the original language, when TMDB provides it.
  final String? languageName;
  final List<CastMember> cast;
  final List<String> directors;
  final MovieVideo? trailer;

  int get id => movie.id;

  static const int maxCast = 15;

  factory MovieDetails.fromJson(Map<String, dynamic> json) {
    final movie = Movie.fromJson(json);
    final credits = json['credits'] as Map<String, dynamic>? ?? const {};
    final crew = credits['crew'] as List<dynamic>? ?? const [];
    final cast = credits['cast'] as List<dynamic>? ?? const [];
    final videos =
        (json['videos'] as Map<String, dynamic>?)?['results']
            as List<dynamic>? ??
        const [];
    final spokenLanguages =
        json['spoken_languages'] as List<dynamic>? ?? const [];

    String? languageName;
    for (final language in spokenLanguages.cast<Map<String, dynamic>>()) {
      if (language['iso_639_1'] == movie.originalLanguage) {
        final name = language['english_name'] as String?;
        if (name != null && name.isNotEmpty) languageName = name;
        break;
      }
    }

    final directors = <String>[];
    for (final member in crew.cast<Map<String, dynamic>>()) {
      final name = member['name'] as String?;
      if (member['job'] == 'Director' &&
          name != null &&
          !directors.contains(name)) {
        directors.add(name);
      }
    }

    return MovieDetails(
      movie: movie,
      tagline: (json['tagline'] as String? ?? '').trim(),
      status: json['status'] as String? ?? '',
      languageName: languageName,
      cast: cast
          .cast<Map<String, dynamic>>()
          .take(maxCast)
          .map(CastMember.fromJson)
          .toList(),
      directors: directors,
      trailer: MovieVideo.pickTrailer(
        videos.cast<Map<String, dynamic>>().map(MovieVideo.fromJson).toList(),
      ),
    );
  }
}

class CastMember {
  const CastMember({
    required this.id,
    required this.name,
    this.character = '',
    this.profilePath,
  });

  final int id;
  final String name;
  final String character;
  final String? profilePath;

  String? get profileUrl {
    if (profilePath == null || profilePath!.isEmpty) return null;
    return 'https://image.tmdb.org/t/p/w185$profilePath';
  }

  factory CastMember.fromJson(Map<String, dynamic> json) => CastMember(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? 'Unknown',
    character: json['character'] as String? ?? '',
    profilePath: json['profile_path'] as String?,
  );
}

class MovieVideo {
  const MovieVideo({
    required this.key,
    required this.name,
    required this.site,
    required this.type,
    this.official = false,
  });

  final String key;
  final String name;
  final String site;
  final String type;
  final bool official;

  Uri get watchUrl => Uri.parse('https://www.youtube.com/watch?v=$key');

  factory MovieVideo.fromJson(Map<String, dynamic> json) => MovieVideo(
    key: json['key'] as String? ?? '',
    name: json['name'] as String? ?? '',
    site: json['site'] as String? ?? '',
    type: json['type'] as String? ?? '',
    official: json['official'] as bool? ?? false,
  );

  /// Best YouTube video to show as "the trailer": official trailers first,
  /// then any trailer, then teasers. Returns `null` when none is playable.
  static MovieVideo? pickTrailer(List<MovieVideo> videos) {
    int rank(MovieVideo v) {
      if (v.site != 'YouTube' || v.key.isEmpty) return 99;
      if (v.type == 'Trailer') return v.official ? 0 : 1;
      if (v.type == 'Teaser') return v.official ? 2 : 3;
      return 99;
    }

    // First video with the best rank (keeps TMDB order among equals).
    MovieVideo? best;
    for (final video in videos) {
      if (rank(video) < (best == null ? 99 : rank(best))) best = video;
    }
    return best;
  }
}
