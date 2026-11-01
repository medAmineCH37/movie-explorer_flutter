import '../models/collection_entry.dart';

abstract class CollectionRepository {
  Future<List<int>> getFavorites();

  Future<List<int>> getWatchlist();

  Future<List<CollectionEntry>> getWatchlistEntries();

  Future<List<CollectionEntry>> getWatchedEntries();

  Future<void> addFavorite(int movieId);

  Future<void> removeFavorite(int movieId);

  Future<void> addToWatchlist(int movieId, {WatchPriority priority});

  Future<void> updateWatchlistPriority(int movieId, WatchPriority priority);

  Future<void> markWatched(int movieId, DateTime watchedAt);

  Future<void> removeWatched(int movieId);

  Future<void> removeFromWatchlist(int movieId);

  Future<bool> isFavorite(int movieId);

  Future<bool> isInWatchlist(int movieId);
}
