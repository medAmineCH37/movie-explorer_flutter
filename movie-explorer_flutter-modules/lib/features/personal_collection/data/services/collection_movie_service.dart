import '../../../movie_management/data/models/movie.dart';
import '../../../movie_management/data/repositories/supabase_movies_repository.dart';
import '../../../movie_management/domain/repositories/movies_repository.dart';

class CollectionMovieService {
  CollectionMovieService({MoviesRepository? repository})
    : _injected = repository;

  final MoviesRepository? _injected;

  late final MoviesRepository _movies = _injected ?? SupabaseMoviesRepository();

  /// Movies in the order of [movieIds]; movies deleted from the catalogue
  /// are skipped.
  Future<List<Movie>> getMoviesByIds(List<int> movieIds) async {
    if (movieIds.isEmpty) {
      return [];
    }

    final found = await _movies.getMoviesByIds(movieIds);
    return [
      for (final id in movieIds)
        if (found[id] != null) found[id]!,
    ];
  }

  void dispose() {}
}
