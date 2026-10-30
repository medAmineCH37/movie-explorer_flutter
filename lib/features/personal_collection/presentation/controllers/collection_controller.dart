import 'package:flutter/foundation.dart';

import '../../../movie_management/data/models/movie.dart';
import '../../domain/repositories/collection_repository.dart';
import '../../data/repositories/collection_repository_impl.dart';
import '../../data/services/collection_movie_service.dart';

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

  bool isFavoritesLoading = false;
  bool isWatchlistLoading = false;

  String? favoritesError;
  String? watchlistError;

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
      final ids = await _repository.getWatchlist();
      watchlist = await _movieService.getMoviesByIds(ids);
    } catch (error) {
      watchlistError = error.toString();
    } finally {
      isWatchlistLoading = false;
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
    await loadWatchlist();
  }

  Future<void> removeFromWatchlist(int movieId) async {
    await _repository.removeFromWatchlist(movieId);
    await loadWatchlist();
  }

  @override
  void dispose() {
    _movieService.dispose();
    super.dispose();
  }
}
