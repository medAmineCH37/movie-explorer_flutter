import 'package:flutter/foundation.dart';

import '../../../movie_management/data/models/genre.dart';
import '../../../movie_management/data/models/movie.dart';
import '../../../movie_management/data/models/movie_search_query.dart';
import '../../../movie_management/domain/repositories/movies_repository.dart';

/// Search, filters, sorting and paging over the movie catalogue.
class DiscoveryController extends ChangeNotifier {
  DiscoveryController({required this.repository});

  final MoviesRepository repository;

  static const int pageSize = 20;

  MovieSearchQuery query = const MovieSearchQuery(sort: MovieSort.popularity);
  List<Movie> movies = [];
  int total = 0;
  int _page = 0;
  bool _hasMore = false;

  List<Genre> genres = const [];
  List<String> languages = const [];

  bool isLoading = false;
  bool isLoadingMore = false;
  String? error;
  String? loadMoreError;

  int _requestId = 0;
  bool _disposed = false;

  bool get hasMore => _hasMore;
  bool get hasSearched => _page > 0;

  /// Loads filter options and the first results.
  Future<void> init() async {
    await Future.wait([_loadOptions(), search()]);
  }

  Future<void> _loadOptions() async {
    try {
      final results = await Future.wait<Object>([
        repository.getGenres(),
        repository.getLanguages(),
      ]);
      genres = results[0] as List<Genre>;
      languages = results[1] as List<String>;
      _notify();
    } catch (_) {
      // Filters stay usable without the option lists (search still works).
    }
  }

  Future<void> setText(String text) {
    if (text.trim() == query.text.trim()) return Future.value();
    return applyQuery(query.copyWith(text: text));
  }

  Future<void> setSort(MovieSort sort) =>
      applyQuery(query.copyWith(sort: () => sort));

  Future<void> applyQuery(MovieSearchQuery next) {
    query = next;
    return search();
  }

  Future<void> clearFilters() => applyQuery(query.clearFilters());

  /// Runs the current query from the first page; stale answers are dropped.
  Future<void> search() async {
    final requestId = ++_requestId;
    isLoading = true;
    error = null;
    loadMoreError = null;
    _notify();

    try {
      final page = await repository.search(query, pageSize: pageSize);
      if (requestId != _requestId) return;
      movies = page.movies;
      total = page.total;
      _page = page.page;
      _hasMore = page.hasMore;
    } on MovieException catch (e) {
      if (requestId == _requestId) error = e.message;
    } catch (_) {
      if (requestId == _requestId) error = 'Could not search movies.';
    } finally {
      if (requestId == _requestId) {
        isLoading = false;
        _notify();
      }
    }
  }

  Future<void> loadMore() async {
    if (isLoading || isLoadingMore || !_hasMore) return;
    final requestId = _requestId;
    isLoadingMore = true;
    loadMoreError = null;
    _notify();

    try {
      final page = await repository.search(
        query,
        page: _page + 1,
        pageSize: pageSize,
      );
      if (requestId != _requestId) return;
      final known = movies.map((m) => m.id).toSet();
      movies = [...movies, ...page.movies.where((m) => known.add(m.id))];
      total = page.total;
      _page = page.page;
      _hasMore = page.hasMore;
    } catch (_) {
      if (requestId == _requestId) loadMoreError = 'Could not load more.';
    } finally {
      if (requestId == _requestId) {
        isLoadingMore = false;
        _notify();
      }
    }
  }

  /// Removes a deleted movie from the results without reloading.
  void movieDeleted(int movieId) {
    final before = movies.length;
    movies = movies.where((m) => m.id != movieId).toList();
    if (movies.length < before) total = total > 0 ? total - 1 : 0;
    _notify();
  }

  String genreName(int id) => genres
      .firstWhere(
        (g) => g.id == id,
        orElse: () => Genre(id: id, name: '#$id'),
      )
      .name;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
