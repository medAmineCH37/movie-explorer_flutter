import 'package:flutter/foundation.dart';

import '../../../movie_management/data/models/movie.dart';
import '../../domain/repositories/collection_repository.dart';
import '../../data/repositories/collection_repository_impl.dart';
import '../../data/services/collection_movie_service.dart';
import '../../domain/models/collection_entry.dart';

class CollectionController extends ChangeNotifier {
  CollectionController({
    CollectionRepository? repository,
    CollectionMovieService? movieService,
  }) : _repository = repository ?? CollectionRepositoryImpl(),
       _movieService = movieService ?? CollectionMovieService();

  final CollectionRepository _repository;
  final CollectionMovieService _movieService;

  List<Movie> favorites = [];
  List<Movie> watchlist = [];
  List<Movie> watched = [];
  final Map<int, WatchPriority> watchlistPriorities = {};
  final Map<int, DateTime> watchedDates = {};

  bool isFavoritesLoading = false;
  bool isWatchlistLoading = false;
  bool isWatchedLoading = false;

  String? favoritesError;
  String? watchlistError;
  String? watchedError;

  Future<void> loadFavorites() async {
    isFavoritesLoading = true;
    favoritesError = null;
    notifyListeners();

    try {
      final ids = await _repository.getFavorites();
      favorites = await _movieService.getMoviesByIds(ids);
    } catch (error) {
      favoritesError = error.toString();
    } finally {
      isFavoritesLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadWatchlist() async {
    isWatchlistLoading = true;
    watchlistError = null;
    notifyListeners();

    try {
      final entries = await _repository.getWatchlistEntries();
      final ids = entries.map((entry) => entry.movieId).toList();
      watchlistPriorities
        ..clear()
        ..addEntries(
          entries.map((entry) => MapEntry(entry.movieId, entry.priority)),
        );
      watchlist = await _movieService.getMoviesByIds(ids);
    } catch (error) {
      watchlistError = error.toString();
    } finally {
      isWatchlistLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadWatched() async {
    isWatchedLoading = true;
    watchedError = null;
    notifyListeners();
    try {
      final entries = await _repository.getWatchedEntries();
      watchedDates
        ..clear()
        ..addEntries(
          entries
              .where((entry) => entry.watchedAt != null)
              .map((entry) => MapEntry(entry.movieId, entry.watchedAt!)),
        );
      watched = await _movieService.getMoviesByIds(
        entries.map((entry) => entry.movieId).toList(),
      );
    } catch (error) {
      watchedError = error.toString();
    } finally {
      isWatchedLoading = false;
      notifyListeners();
    }
  }

  Future<void> addFavorite(int movieId) async {
    await _repository.addFavorite(movieId);
    await loadFavorites();
  }

  Future<void> removeFavorite(int movieId) async {
    await _repository.removeFavorite(movieId);
    await loadFavorites();
  }

  Future<void> addToWatchlist(int movieId) async {
    await _repository.addToWatchlist(movieId);
    watchedDates.remove(movieId);
    await loadWatchlist();
    await loadWatched();
  }

  Future<void> removeFromWatchlist(int movieId) async {
    await _repository.removeFromWatchlist(movieId);
    await loadWatchlist();
  }

  Future<void> updatePriority(int movieId, WatchPriority priority) async {
    await _repository.updateWatchlistPriority(movieId, priority);
    watchlistPriorities[movieId] = priority;
    notifyListeners();
  }

  Future<void> markWatched(int movieId, DateTime watchedAt) async {
    await _repository.markWatched(movieId, watchedAt);
    await Future.wait([loadWatchlist(), loadWatched()]);
  }

  Future<void> removeWatched(int movieId) async {
    await _repository.removeWatched(movieId);
    await loadWatched();
  }

  @override
  void dispose() {
    _movieService.dispose();
    super.dispose();
  }
}
