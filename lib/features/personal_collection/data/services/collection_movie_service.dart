
import '../../../movie_management/data/models/movie.dart';
import '../../../movie_management/data/services/tmdb_service.dart';

class CollectionMovieService {
  CollectionMovieService({TmdbService? tmdbService})
      : _tmdbService = tmdbService ?? TmdbService();

  final TmdbService _tmdbService;

  Future<List<Movie>> getMoviesByIds(List<int> movieIds) async {
    if (movieIds.isEmpty) {
      return [];
    }

    final movies = await Future.wait(
      movieIds.map((id) async {
        final details = await _tmdbService.getMovieDetails(id);
        return Movie.fromJson(details);
      }),
    );

    return movies;
  }

  void dispose() {
    _tmdbService.dispose();
  }
}
