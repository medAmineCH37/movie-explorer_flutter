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
  Future<void> addFavorite(int movieId) {
    return _service.addFavorite(movieId);
  }

  @override
  Future<void> removeFavorite(int movieId) {
    return _service.removeFavorite(movieId);
  }

  @override
  Future<void> addToWatchlist(int movieId) {
    return _service.addToWatchlist(movieId);
  }

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
