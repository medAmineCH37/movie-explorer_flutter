import 'package:flutter/foundation.dart';

import '../../../movie_management/data/models/movie.dart';
import '../../../movie_management/data/repositories/supabase_movies_repository.dart';
import '../../data/repositories/reviews_repository_impl.dart';
import '../../domain/models/review.dart';
import '../../domain/models/review_activity.dart';
import '../../domain/repositories/reviews_repository.dart';

/// Loads catalogue movies for activity items, keyed by id. Ids missing from
/// the result were deleted from the catalogue; the items stay manageable.
typedef MovieLookup = Future<Map<int, Movie>> Function(List<int> movieIds);

/// "My ratings & reviews" screen state.
class MyRatingsController extends ChangeNotifier {
  MyRatingsController({ReviewsRepository? repository, this.lookup})
    : _repository = repository ?? ReviewsRepositoryImpl();

  final ReviewsRepository _repository;
  MovieLookup? lookup;

  List<ReviewActivity> items = [];
  final Map<int, Movie?> movies = {};
  ReviewStats stats = const ReviewStats(
    ratedCount: 0,
    averageScore: null,
    likesReceived: 0,
  );

  bool isLoading = false;
  String? error;
  final Set<int> busyMovieIds = {};
  bool _disposed = false;

  ReviewsRepository get repository => _repository;
  bool get isSignedIn => _repository.currentUserId != null;

  MovieLookup get _movieLookup =>
      lookup ??= SupabaseMoviesRepository().getMoviesByIds;

  Future<void> load() async {
    if (!isSignedIn) {
      items = [];
      _notify();
      return;
    }
    isLoading = true;
    error = null;
    _notify();

    try {
      items = await _repository.getMyActivity();
      _recomputeStats();
      await _loadMissingMovies();
    } on ReviewException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Could not load your ratings and reviews.';
    } finally {
      isLoading = false;
      _notify();
    }
  }

  /// Whether metadata for [movieId] was fetched (even if the movie is gone).
  bool hasMovieInfo(int movieId) => movies.containsKey(movieId);

  /// `true` when TMDB reported the movie as removed.
  bool isMovieRemoved(int movieId) =>
      movies.containsKey(movieId) && movies[movieId] == null;

  Future<void> rate(int movieId, int score) => _mutate(movieId, () async {
    await _repository.rateMovie(movieId, score);
    _replace(movieId, (item) => _withScore(item, score));
  });

  Future<void> removeRating(int movieId) => _mutate(movieId, () async {
    await _repository.removeRating(movieId);
    _replace(movieId, (item) => _withScore(item, null));
  });

  Future<void> deleteReview(ReviewActivity item) =>
      _mutate(item.movieId, () async {
        await _repository.deleteReview(item.review!.id);
        _replace(
          item.movieId,
          (i) => i.score == null
              ? null
              : ReviewActivity(
                  movieId: i.movieId,
                  score: i.score,
                  updatedAt: i.updatedAt,
                ),
        );
      });

  /// Called after the composer saved [review] for [movieId].
  void reviewSaved(int movieId, Review review) {
    _replace(
      movieId,
      (i) => ReviewActivity(
        movieId: i.movieId,
        score: i.score,
        review: review,
        updatedAt: DateTime.now(),
      ),
    );
    _notify();
  }

  Future<void> _mutate(int movieId, Future<void> Function() action) async {
    busyMovieIds.add(movieId);
    _notify();
    try {
      await action();
    } finally {
      busyMovieIds.remove(movieId);
      _notify();
    }
  }

  ReviewActivity? _withScore(ReviewActivity item, int? score) {
    if (score == null && item.review == null) return null;
    return ReviewActivity(
      movieId: item.movieId,
      score: score,
      review: item.review?.copyWith(score: () => score),
      updatedAt: DateTime.now(),
    );
  }

  /// Replaces the item of [movieId]; a `null` result removes it.
  void _replace(int movieId, ReviewActivity? Function(ReviewActivity) update) {
    final next = <ReviewActivity>[];
    for (final item in items) {
      if (item.movieId != movieId) {
        next.add(item);
        continue;
      }
      final updated = update(item);
      if (updated != null) next.add(updated);
    }
    items = next;
    _recomputeStats();
  }

  void _recomputeStats() => stats = ReviewStats.from(items);

  Future<void> _loadMissingMovies() async {
    final missing = items
        .map((i) => i.movieId)
        .where((id) => !movies.containsKey(id))
        .toList();
    if (missing.isEmpty) return;
    try {
      final found = await _movieLookup(missing);
      for (final id in missing) {
        movies[id] = found[id];
      }
    } catch (_) {
      // Network error: leave them unknown so the cards show a placeholder
      // without claiming the movies were removed.
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
