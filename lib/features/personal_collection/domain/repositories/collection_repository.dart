abstract class CollectionRepository {
  Future<List<int>> getFavorites();

  Future<List<int>> getWatchlist();

  Future<void> addFavorite(int movieId);

  Future<void> removeFavorite(int movieId);

  Future<void> addToWatchlist(int movieId);

  Future<void> removeFromWatchlist(int movieId);

  Future<bool> isFavorite(int movieId);

  Future<bool> isInWatchlist(int movieId);
}
