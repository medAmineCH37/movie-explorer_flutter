import 'package:flutter/foundation.dart';

import '../../data/models/movie.dart';
import '../../data/models/movie_category.dart';
import '../../data/services/tmdb_service.dart';

/// Paginated state of one TMDB catalogue list.
class MovieCatalogController extends ChangeNotifier {
  MovieCatalogController({required this.category, required this.tmdbService});

  final MovieCategory category;
  final TmdbService tmdbService;

  final List<Movie> movies = [];
  int _page = 0;
  bool _hasMore = true;

  bool isLoading = false;
  bool isLoadingMore = false;
  String? error;
  String? loadMoreError;

  bool get hasMore => _hasMore;
  bool get hasLoaded => _page > 0;

  /// Loads (or reloads) the first page.
  Future<void> loadInitial() async {
    isLoading = true;
    error = null;
    loadMoreError = null;
    notifyListeners();

    try {
      final page = await tmdbService.getMovies(category);
      movies
        ..clear()
        ..addAll(page.movies);
      _page = page.page;
      _hasMore = page.hasMore;
    } catch (e) {
      error = 'Could not load ${category.label.toLowerCase()} movies.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Appends the next page; ignored while a request is running.
  Future<void> loadMore() async {
    if (isLoading || isLoadingMore || !_hasMore || !hasLoaded) return;

    isLoadingMore = true;
    loadMoreError = null;
    notifyListeners();

    try {
      final page = await tmdbService.getMovies(category, page: _page + 1);
      // TMDB lists shift while paging; skip movies already shown.
      final known = movies.map((m) => m.id).toSet();
      movies.addAll(page.movies.where((m) => known.add(m.id)));
      _page = page.page;
      _hasMore = page.hasMore;
    } catch (e) {
      loadMoreError = 'Could not load more movies.';
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }
}
