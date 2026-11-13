import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ids of the signed-in user's favorite movies (table `favorites`, Module 4).
/// Lets any poster show a heart without querying Supabase per card.
class FavoriteIdsStore extends ChangeNotifier {
  FavoriteIdsStore._() {
    final client = _clientOrNull;
    if (client == null) return; // Supabase not initialized (widget tests).
    // Singleton kept for the app lifetime: the subscription is never cancelled.
    client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        _ids = {};
        notifyListeners();
      } else if (data.event == AuthChangeEvent.signedIn) {
        unawaited(refresh());
      }
    });
    unawaited(refresh());
  }

  static final FavoriteIdsStore instance = FavoriteIdsStore._();

  Set<int> _ids = {};

  bool contains(int movieId) => _ids.contains(movieId);

  static SupabaseClient? get _clientOrNull {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<void> refresh() async {
    final client = _clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      if (_ids.isNotEmpty) {
        _ids = {};
        notifyListeners();
      }
      return;
    }
    try {
      final rows = await client
          .from('favorites')
          .select('tmdb_movie_id')
          .eq('user_id', userId);
      _ids = rows.map((r) => (r['tmdb_movie_id'] as num).toInt()).toSet();
      notifyListeners();
    } catch (_) {
      // Hearts are decorative: a failed load never blocks a screen.
    }
  }

  /// Called after a favorite is added or removed elsewhere in the app.
  void setFavorite(int movieId, bool isFavorite) {
    final changed = isFavorite ? _ids.add(movieId) : _ids.remove(movieId);
    if (changed) notifyListeners();
  }
}
