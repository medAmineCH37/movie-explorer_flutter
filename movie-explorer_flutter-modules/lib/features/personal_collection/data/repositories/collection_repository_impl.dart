import '../../domain/models/collection_entry.dart';
import '../../domain/repositories/collection_repository.dart';
import '../services/collection_service.dart';

class CollectionRepositoryImpl implements CollectionRepository {
  CollectionRepositoryImpl({CollectionService? service})
    : _service = service ?? CollectionService();

  final CollectionService _service;

  @override
  Future<List<int>> getFavorites() {
    return _service.getFavorites();
  }

  @override
  Future<List<int>> getWatchlist() {
    return _service.getWatchlist();
  }

  @override
  Future<List<CollectionEntry>> getWatchlistEntries() =>
      _service.getWatchlistEntries();

  @override
  Future<List<CollectionEntry>> getWatchedEntries() =>
      _service.getWatchedEntries();

  @override
  Future<void> addFavorite(int movieId) {
    return _service.addFavorite(movieId);
  }

  @override
  Future<void> removeFavorite(int movieId) {
    return _service.removeFavorite(movieId);
  }

  @override
  Future<void> addToWatchlist(
    int movieId, {
    WatchPriority priority = WatchPriority.medium,
  }) {
    return _service.addToWatchlist(movieId, priority: priority);
  }

  @override
  Future<void> updateWatchlistPriority(int movieId, WatchPriority priority) =>
      _service.updateWatchlistPriority(movieId, priority);

  @override
  Future<void> markWatched(int movieId, DateTime watchedAt) =>
      _service.markWatched(movieId, watchedAt);

  @override
  Future<void> removeWatched(int movieId) => _service.removeWatched(movieId);

  @override
  Future<void> removeFromWatchlist(int movieId) {
    return _service.removeFromWatchlist(movieId);
  }

  @override
  Future<bool> isFavorite(int movieId) {
    return _service.isFavorite(movieId);
  }

  @override
  Future<bool> isInWatchlist(int movieId) {
    return _service.isInWatchlist(movieId);
  }
}
