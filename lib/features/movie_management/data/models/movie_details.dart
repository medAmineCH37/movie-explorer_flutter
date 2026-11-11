import 'genre.dart';
import 'languages.dart';
import 'movie.dart';

/// Full movie record: `movies` row with embedded genres and credits.
class MovieDetails {
  const MovieDetails({
    required this.movie,
    this.originalTitle = '',
    this.tagline = '',
    this.status = 'Released',
    this.genres = const [],
    this.cast = const [],
    this.directors = const [],
    this.trailer,
    this.createdBy,
  });

  /// PostgREST `select` for [MovieDetails.fromJson].
  static const String selectColumns =
      '*, movie_genres(genres(id, name)), '
      'movie_credits(kind, name, character, profile_url, position)';

  final Movie movie;
  final String originalTitle;
  final String tagline;
  final String status;
  final List<Genre> genres;
  final List<CastMember> cast;
  final List<String> directors;
  final MovieVideo? trailer;

  /// User who added the movie in the app (`null` for seeded movies).
  final String? createdBy;

  int get id => movie.id;

  String? get languageName {
    final code = movie.originalLanguage;
    return code == null ? null : Languages.nameOf(code);
  }

  factory MovieDetails.fromJson(Map<String, dynamic> json) {
    final genres = <Genre>[
      for (final link in json['movie_genres'] as List? ?? const [])
        if (link is Map && link['genres'] is Map)
          Genre.fromJson(Map<String, dynamic>.from(link['genres'] as Map)),
    ]..sort((a, b) => a.name.compareTo(b.name));

    final credits =
        (json['movie_credits'] as List? ?? const [])
            .map((c) => Map<String, dynamic>.from(c as Map))
            .toList()
          ..sort(
            (a, b) => ((a['position'] as num?) ?? 0).compareTo(
              (b['position'] as num?) ?? 0,
            ),
          );

    final movie = Movie.fromJson({
      ...json,
      'genres': [for (final g in genres) g.name],
    });
    final trailerKey = json['trailer_youtube_key'] as String?;

    return MovieDetails(
      movie: movie,
      originalTitle: json['original_title'] as String? ?? '',
      tagline: (json['tagline'] as String? ?? '').trim(),
      status: json['status'] as String? ?? 'Released',
      genres: genres,
      directors: [
        for (final c in credits)
          if (c['kind'] == 'director') c['name'] as String,
      ],
      cast: [
        for (final c in credits)
          if (c['kind'] == 'cast') CastMember.fromJson(c),
      ],
      trailer: trailerKey == null || trailerKey.isEmpty
          ? null
          : MovieVideo(key: trailerKey),
      createdBy: json['created_by'] as String?,
    );
  }
}

class CastMember {
  const CastMember({required this.name, this.character = '', this.profileUrl});

  final String name;
  final String character;
  final String? profileUrl;

  factory CastMember.fromJson(Map<String, dynamic> json) => CastMember(
    name: json['name'] as String? ?? 'Unknown',
    character: json['character'] as String? ?? '',
    profileUrl: json['profile_url'] as String?,
  );
}

/// A YouTube trailer.
class MovieVideo {
  const MovieVideo({required this.key});

  final String key;

  Uri get watchUrl => Uri.parse('https://www.youtube.com/watch?v=$key');

  static final RegExp _keyPattern = RegExp(r'^[A-Za-z0-9_-]{6,20}$');

  /// Extracts the video key from a YouTube URL (watch, youtu.be, embed,
  /// shorts) or returns [input] when it already is a key. `null` if invalid.
  static String? parseKey(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;
    if (_keyPattern.hasMatch(text)) return text;

    final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
    if (uri == null) return null;
    final host = uri.host.replaceFirst('www.', '').replaceFirst('m.', '');
    String? key;
    if (host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
      key = uri.pathSegments.first;
    } else if (host == 'youtube.com' || host == 'music.youtube.com') {
      final segments = uri.pathSegments;
      if (segments.isNotEmpty && segments.first == 'watch') {
        key = uri.queryParameters['v'];
      } else if (segments.length >= 2 &&
          const {'embed', 'shorts', 'v', 'live'}.contains(segments.first)) {
        key = segments[1];
      }
    }
    return key != null && _keyPattern.hasMatch(key) ? key : null;
  }
}
