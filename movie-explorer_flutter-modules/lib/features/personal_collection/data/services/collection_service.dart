import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/collection_entry.dart';

class CollectionService {
  CollectionService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('User must be authenticated.');
    }

    return user.id;
  }

  Future<List<int>> getFavorites() async {
    final response = await _client
        .from('favorites')
        .select('tmdb_movie_id')
        .eq('user_id', _userId);

    return response.map((item) => item['tmdb_movie_id'] as int).toList();
  }

  Future<List<int>> getWatchlist() async {
    final response = await _client
        .from('watchlist')
        .select('tmdb_movie_id')
        .eq('user_id', _userId);

    return response.map((item) => item['tmdb_movie_id'] as int).toList();
  }

  Future<List<CollectionEntry>> getWatchlistEntries() async {
    final response = await _client
        .from('watchlist')
        .select('tmdb_movie_id, priority')
        .eq('user_id', _userId);
    return response
        .map(
          (item) => CollectionEntry(
            movieId: item['tmdb_movie_id'] as int,
            priority: WatchPriority.fromValue(item['priority']),
          ),
        )
        .toList();
  }

  Future<List<CollectionEntry>> getWatchedEntries() async {
    final response = await _client
        .from('watched_movies')
        .select('tmdb_movie_id, watched_at')
        .eq('user_id', _userId)
        .order('watched_at', ascending: false);
    return response
        .map(
          (item) => CollectionEntry(
            movieId: item['tmdb_movie_id'] as int,
            watchedAt: DateTime.tryParse(item['watched_at'] as String),
          ),
        )
        .toList();
  }

  Future<void> addFavorite(int movieId) async {
    await _client.from('favorites').upsert({
      'user_id': _userId,
      'tmdb_movie_id': movieId,
    }, onConflict: 'user_id,tmdb_movie_id');
  }

  Future<void> removeFavorite(int movieId) async {
    await _client
        .from('favorites')
        .delete()
        .eq('user_id', _userId)
        .eq('tmdb_movie_id', movieId);
  }

  Future<void> addToWatchlist(
    int movieId, {
    WatchPriority priority = WatchPriority.medium,
  }) async {
    await _client.from('watchlist').upsert({
      'user_id': _userId,
      'tmdb_movie_id': movieId,
      'priority': priority.value,
    }, onConflict: 'user_id,tmdb_movie_id');
    await removeWatched(movieId);
  }

  Future<void> updateWatchlistPriority(
    int movieId,
    WatchPriority priority,
  ) async {
    await _client
        .from('watchlist')
        .update({'priority': priority.value})
        .eq('user_id', _userId)
        .eq('tmdb_movie_id', movieId);
  }

  Future<void> markWatched(int movieId, DateTime watchedAt) async {
    await _client.from('watched_movies').upsert({
      'user_id': _userId,
      'tmdb_movie_id': movieId,
      'watched_at': watchedAt.toIso8601String().split('T').first,
    }, onConflict: 'user_id,tmdb_movie_id');
    await removeFromWatchlist(movieId);
  }

  Future<void> removeWatched(int movieId) async {
    await _client
        .from('watched_movies')
        .delete()
        .eq('user_id', _userId)
        .eq('tmdb_movie_id', movieId);
  }

  Future<void> removeFromWatchlist(int movieId) async {
    await _client
        .from('watchlist')
        .delete()
        .eq('user_id', _userId)
        .eq('tmdb_movie_id', movieId);
  }

  Future<bool> isFavorite(int movieId) async {
    final response = await _client
        .from('favorites')
        .select('id')
        .eq('user_id', _userId)
        .eq('tmdb_movie_id', movieId)
        .maybeSingle();

    return response != null;
  }

  Future<bool> isInWatchlist(int movieId) async {
    final response = await _client
        .from('watchlist')
        .select('id')
        .eq('user_id', _userId)
        .eq('tmdb_movie_id', movieId)
        .maybeSingle();

    return response != null;
  }
}
