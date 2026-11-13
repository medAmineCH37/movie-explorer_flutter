import 'movie_details.dart';

/// Editable movie fields (create/edit form), validated before saving.
///
/// The database enforces the same limits (CHECK constraints in
/// `supabase/migrations/20261112_movies_catalogue.sql`).
class MovieDraft {
  MovieDraft({
    this.title = '',
    this.originalTitle = '',
    this.tagline = '',
    this.overview = '',
    this.releaseDate,
    this.runtime = '',
    this.language,
    this.posterUrl = '',
    this.backdropUrl = '',
    this.trailer = '',
    this.rating = '',
    this.status = 'Released',
    Set<int>? genreIds,
    this.directors = '',
    List<CastDraft>? cast,
  }) : genreIds = genreIds ?? {},
       cast = cast ?? [];

  static const int maxTitle = 200;
  static const int maxTagline = 300;
  static const int maxOverview = 5000;
  static const int maxDirectors = 10;
  static const int maxCast = 30;
  static const int maxPersonName = 120;
  static const int maxCharacter = 200;

  static const List<String> statuses = [
    'Released',
    'Post Production',
    'In Production',
    'Planned',
    'Rumored',
    'Canceled',
  ];

  String title;
  String originalTitle;
  String tagline;
  String overview;
  DateTime? releaseDate;

  /// Minutes, as typed.
  String runtime;
  String? language;
  String posterUrl;
  String backdropUrl;

  /// YouTube URL or video key.
  String trailer;

  /// 0–10, as typed.
  String rating;
  String status;
  Set<int> genreIds;

  /// Comma-separated names.
  String directors;
  List<CastDraft> cast;

  factory MovieDraft.fromDetails(MovieDetails d) {
    final m = d.movie;
    return MovieDraft(
      title: m.title,
      originalTitle: d.originalTitle,
      tagline: d.tagline,
      overview: m.overview,
      releaseDate: DateTime.tryParse(m.releaseDate),
      runtime: m.runtime?.toString() ?? '',
      language: m.originalLanguage,
      posterUrl: m.posterUrl ?? '',
      backdropUrl: m.backdropUrl ?? '',
      trailer: d.trailer?.key ?? '',
      rating: m.voteAverage == 0 ? '' : m.voteAverage.toStringAsFixed(1),
      status: statuses.contains(d.status) ? d.status : 'Released',
      genreIds: {for (final g in d.genres) g.id},
      directors: d.directors.join(', '),
      cast: [
        for (final c in d.cast) CastDraft(name: c.name, character: c.character),
      ],
    );
  }

  List<String> get directorNames => directors
      .split(',')
      .map((d) => d.trim())
      .where((d) => d.isNotEmpty)
      .toList();

  // --- Field validators (return an error message or null) -----------------

  static String? validateTitle(String value) {
    final length = value.trim().length;
    if (length == 0) return 'The title is required.';
    if (length > maxTitle) return 'At most $maxTitle characters.';
    return null;
  }

  static String? validateMaxLength(String value, int max) =>
      value.trim().length > max ? 'At most $max characters.' : null;

  static String? validateRuntime(String value) {
    if (value.trim().isEmpty) return null;
    final minutes = int.tryParse(value.trim());
    if (minutes == null || minutes < 1 || minutes > 1000) {
      return 'Enter minutes between 1 and 1000.';
    }
    return null;
  }

  static String? validateRating(String value) {
    if (value.trim().isEmpty) return null;
    final rating = double.tryParse(value.trim().replaceAll(',', '.'));
    if (rating == null || rating < 0 || rating > 10) {
      return 'Enter a rating between 0 and 10.';
    }
    return null;
  }

  static String? validateImageUrl(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        text.contains(' ')) {
      return 'Use an https:// image link.';
    }
    return null;
  }

  static String? validateTrailer(String value) {
    if (value.trim().isEmpty) return null;
    return MovieVideo.parseKey(value) == null
        ? 'Paste a YouTube link or video id.'
        : null;
  }

  static String? validateDirectors(String value) {
    final names = value
        .split(',')
        .map((d) => d.trim())
        .where((d) => d.isNotEmpty);
    if (names.length > maxDirectors) {
      return 'At most $maxDirectors directors.';
    }
    if (names.any((n) => n.length > maxPersonName)) {
      return 'Names have at most $maxPersonName characters.';
    }
    return null;
  }

  /// All errors by field name; empty when the draft can be saved.
  Map<String, String> validate() {
    final errors = <String, String>{
      'title': ?validateTitle(title),
      'originalTitle': ?validateMaxLength(originalTitle, maxTitle),
      'tagline': ?validateMaxLength(tagline, maxTagline),
      'overview': ?validateMaxLength(overview, maxOverview),
      'runtime': ?validateRuntime(runtime),
      'rating': ?validateRating(rating),
      'posterUrl': ?validateImageUrl(posterUrl),
      'backdropUrl': ?validateImageUrl(backdropUrl),
      'trailer': ?validateTrailer(trailer),
      'directors': ?validateDirectors(directors),
    };
    final namedCast = cast.where((c) => c.name.trim().isNotEmpty).toList();
    if (namedCast.length > maxCast) {
      errors['cast'] = 'At most $maxCast cast members.';
    } else if (namedCast.any(
      (c) =>
          c.name.trim().length > maxPersonName ||
          c.character.trim().length > maxCharacter,
    )) {
      errors['cast'] = 'A cast name or role is too long.';
    }
    return errors;
  }

  /// Parameters of the `save_movie` database function.
  Map<String, dynamic> toRpcParams(int? movieId) {
    final date = releaseDate;
    return {
      'p_id': movieId,
      'p_movie': {
        'title': title.trim(),
        'original_title': originalTitle.trim(),
        'tagline': tagline.trim(),
        'overview': overview.trim(),
        'release_date': date == null
            ? ''
            : '${date.year.toString().padLeft(4, '0')}-'
                  '${date.month.toString().padLeft(2, '0')}-'
                  '${date.day.toString().padLeft(2, '0')}',
        'runtime': runtime.trim(),
        'original_language': language ?? '',
        'poster_url': posterUrl.trim(),
        'backdrop_url': backdropUrl.trim(),
        'trailer_youtube_key': MovieVideo.parseKey(trailer) ?? '',
        'vote_average': rating.trim().replaceAll(',', '.'),
        'status': status,
      },
      'p_genre_ids': genreIds.toList()..sort(),
      'p_directors': directorNames,
      'p_cast': [
        for (final c in cast)
          if (c.name.trim().isNotEmpty)
            {'name': c.name.trim(), 'character': c.character.trim()},
      ],
    };
  }
}

class CastDraft {
  CastDraft({this.name = '', this.character = ''});

  String name;
  String character;
}
