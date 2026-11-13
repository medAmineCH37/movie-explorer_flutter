import 'package:movie_explorer/features/movie_management/data/models/genre.dart';
import 'package:movie_explorer/features/movie_management/data/models/movie.dart';
import 'package:movie_explorer/features/movie_management/data/models/movie_category.dart';
import 'package:movie_explorer/features/movie_management/data/models/movie_details.dart';
import 'package:movie_explorer/features/movie_management/data/models/movie_draft.dart';
import 'package:movie_explorer/features/movie_management/data/models/movie_page.dart';
import 'package:movie_explorer/features/movie_management/data/models/movie_search_query.dart';
import 'package:movie_explorer/features/movie_management/domain/repositories/movies_repository.dart';

const testGenres = [
  Genre(id: 18, name: 'Drama'),
  Genre(id: 28, name: 'Action'),
  Genre(id: 35, name: 'Comedy'),
];

class FakeMovie {
  FakeMovie({
    required this.id,
    required this.title,
    this.year = 2020,
    this.rating = 7,
    this.votes = 100,
    this.popularity = 10,
    this.language = 'en',
    this.genreIds = const {18},
    this.poster,
  });

  final int id;
  String title;
  int? year;
  double rating;
  int votes;
  double popularity;
  String? language;
  Set<int> genreIds;
  String? poster;
  String overview = '';
  List<String> directors = const [];
  List<CastMember> cast = const [];

  Movie toMovie() => Movie(
    id: id,
    title: title,
    overview: overview,
    posterPath: poster,
    backdropPath: null,
    voteAverage: rating,
    voteCount: votes,
    releaseDate: year == null ? '' : '$year-06-01',
    originalLanguage: language,
    genres: [
      for (final g in testGenres)
        if (genreIds.contains(g.id)) g.name,
    ],
  );
}

/// In-memory [MoviesRepository] with the same filtering rules as the
/// `search_movies` database function.
class FakeMoviesRepository extends MoviesRepository {
  FakeMoviesRepository({List<FakeMovie>? movies, this.userId = 'user-1'})
    : movies = movies ?? [];

  final List<FakeMovie> movies;
  String? userId;
  int _nextId = 100000000;
  final List<String> calls = [];
  MovieException? failWith;
  MovieDraft? lastSaved;

  @override
  String? get currentUserId => userId;

  void _call(String name) {
    calls.add(name);
    if (failWith != null) throw failWith!;
  }

  @override
  Future<MoviePage> getCategory(
    MovieCategory category, {
    int page = 1,
    int pageSize = 20,
  }) => search(
    MovieSearchQuery(category: category),
    page: page,
    pageSize: pageSize,
  );

  @override
  Future<MoviePage> search(
    MovieSearchQuery query, {
    int page = 1,
    int pageSize = 20,
  }) async {
    _call('search:${query.category?.slug ?? '-'}:$page');
    final text = query.text.trim().toLowerCase();
    var list = movies.where((m) {
      final year = m.year;
      return (text.isEmpty || m.title.toLowerCase().contains(text)) &&
          (query.genreIds.isEmpty || m.genreIds.any(query.genreIds.contains)) &&
          (query.yearFrom == null ||
              (year != null && year >= query.yearFrom!)) &&
          (query.yearTo == null || (year != null && year <= query.yearTo!)) &&
          (query.minRating == null || m.rating >= query.minRating!) &&
          (query.language == null || m.language == query.language);
    }).toList();

    switch (query.sort ?? MovieSort.popularity) {
      case MovieSort.popularity:
        list.sort((a, b) => b.popularity.compareTo(a.popularity));
      case MovieSort.rating:
        list.sort((a, b) => b.rating.compareTo(a.rating));
      case MovieSort.newest:
        list.sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
      case MovieSort.oldest:
        list.sort((a, b) => (a.year ?? 9999).compareTo(b.year ?? 9999));
      case MovieSort.title:
        list.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
    }
    list = list.toList();

    return MoviePage(
      movies: list
          .skip((page - 1) * pageSize)
          .take(pageSize)
          .map((m) => m.toMovie())
          .toList(),
      page: page,
      total: list.length,
      pageSize: pageSize,
    );
  }

  @override
  Future<MovieDetails?> getMovie(int id) async {
    _call('get:$id');
    final m = movies.where((m) => m.id == id).firstOrNull;
    if (m == null) return null;
    return MovieDetails(
      movie: m.toMovie(),
      genres: [
        for (final g in testGenres)
          if (m.genreIds.contains(g.id)) g,
      ],
      directors: m.directors,
      cast: m.cast,
    );
  }

  @override
  Future<Map<int, Movie>> getMoviesByIds(Iterable<int> ids) async {
    _call('byIds');
    final wanted = ids.toSet();
    return {
      for (final m in movies)
        if (wanted.contains(m.id)) m.id: m.toMovie(),
    };
  }

  @override
  Future<List<Genre>> getGenres() async => testGenres;

  @override
  Future<List<String>> getLanguages() async =>
      {for (final m in movies) ?m.language}.toList();

  @override
  Future<int> createMovie(MovieDraft draft) async {
    _call('create');
    _requireUser();
    final errors = draft.validate();
    if (errors.isNotEmpty) throw MovieException(errors.values.first);
    lastSaved = draft;
    final movie = FakeMovie(
      id: _nextId++,
      title: draft.title.trim(),
      year: draft.releaseDate?.year,
      rating: double.tryParse(draft.rating) ?? 0,
      votes: 0,
      popularity: 0,
      language: draft.language,
      genreIds: {...draft.genreIds},
    )..directors = draft.directorNames;
    movies.add(movie);
    return movie.id;
  }

  @override
  Future<void> updateMovie(int id, MovieDraft draft) async {
    _call('update:$id');
    _requireUser();
    lastSaved = draft;
    final m = movies.firstWhere(
      (m) => m.id == id,
      orElse: () => throw const MovieException('This movie no longer exists.'),
    );
    m
      ..title = draft.title.trim()
      ..year = draft.releaseDate?.year
      ..genreIds = {...draft.genreIds}
      ..directors = draft.directorNames;
  }

  @override
  Future<void> deleteMovie(int id) async {
    _call('delete:$id');
    _requireUser();
    final before = movies.length;
    movies.removeWhere((m) => m.id == id);
    if (movies.length == before) {
      throw const MovieException('This movie no longer exists.');
    }
  }

  void _requireUser() {
    if (userId == null) {
      throw const MovieException(
        'Sign in to manage movies.',
        requiresSignIn: true,
      );
    }
  }
}
