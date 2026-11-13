import '../../data/models/genre.dart';
import '../../data/models/movie.dart';
import '../../data/models/movie_category.dart';
import '../../data/models/movie_details.dart';
import '../../data/models/movie_draft.dart';
import '../../data/models/movie_page.dart';
import '../../data/models/movie_search_query.dart';

/// Thrown with a message that can be shown to the user as is.
class MovieException implements Exception {
  const MovieException(this.message, {this.requiresSignIn = false});

  final String message;
  final bool requiresSignIn;

  @override
  String toString() => message;
}

/// Movie catalogue stored in Supabase (Movie Management and Discovery).
abstract class MoviesRepository {
  /// Signed-in user id; any signed-in user may add, edit and delete movies.
  String? get currentUserId;

  bool get canEdit => currentUserId != null;

  Future<MoviePage> getCategory(
    MovieCategory category, {
    int page = 1,
    int pageSize = 20,
  });

  Future<MoviePage> search(
    MovieSearchQuery query, {
    int page = 1,
    int pageSize = 20,
  });

  /// `null` when the movie is not (or no longer) in the catalogue.
  Future<MovieDetails?> getMovie(int id);

  /// Movies that still exist, keyed by id.
  Future<Map<int, Movie>> getMoviesByIds(Iterable<int> ids);

  Future<List<Genre>> getGenres();

  /// Language codes present in the catalogue, most frequent first.
  Future<List<String>> getLanguages();

  /// Returns the new movie id.
  Future<int> createMovie(MovieDraft draft);

  Future<void> updateMovie(int id, MovieDraft draft);

  Future<void> deleteMovie(int id);
}
