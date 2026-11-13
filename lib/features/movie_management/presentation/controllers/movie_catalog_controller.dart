import 'package:flutter/foundation.dart';

import '../../data/models/movie.dart';
import '../../data/models/movie_category.dart';
import '../../domain/repositories/movies_repository.dart';

/// Paginated state of one catalogue list.
class MovieCatalogController extends ChangeNotifier {
  MovieCatalogController({required this.category, required this.repository});

  final MovieCategory category;
  final MoviesRepository repository;

  static const int pageSize = 20;

  final List<Movie> movies = [];
  int _page = 0;
  bool _hasMore = true;

  bool isLoading = false;
  bool isLoadingMore = false;
  String? error;
  String? loadMoreError;
  bool _disposed = false;

  bool get hasMore => _hasMore;
  bool get hasLoaded => _page > 0;

  /// Loads (or reloads) the first page.
  Future<void> loadInitial() async {
    isLoading = true;
    error = null;
    loadMoreError = null;
    _notify();

    try {
      final page = await repository.getCategory(category, pageSize: pageSize);
      movies
        ..clear()
        ..addAll(page.movies);
      _page = page.page;
      _hasMore = page.hasMore;
    } catch (e) {
      error = 'Could not load ${category.label.toLowerCase()} movies.';
    } finally {
      isLoading = false;
      _notify();
    }
  }

  /// Appends the next page; ignored while a request is running.
  Future<void> loadMore() async {
    if (isLoading || isLoadingMore || !_hasMore || !hasLoaded) return;

    isLoadingMore = true;
    loadMoreError = null;
    _notify();

    try {
      final page = await repository.getCategory(
        category,
        page: _page + 1,
        pageSize: pageSize,
      );
      // Rows can shift while paging (edits, deletes); skip duplicates.
      final known = movies.map((m) => m.id).toSet();
      movies.addAll(page.movies.where((m) => known.add(m.id)));
      _page = page.page;
      _hasMore = page.hasMore;
    } catch (e) {
      loadMoreError = 'Could not load more movies.';
    } finally {
      isLoadingMore = false;
      _notify();
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
