import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/list_rules.dart';
import '../domain/models/custom_list.dart';
import '../domain/ranking.dart';
import 'list_changes.dart';
import 'reco_tmdb_service.dart';

/// Custom lists in Supabase. Rules are checked here for clear messages and
/// enforced again by the database (constraints, triggers, RLS).
class CustomListRepository {
  CustomListRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  String get _userId {
    final id = currentUserId;
    if (id == null) throw const RecoException('Sign in to manage your lists.');
    return id;
  }

  Future<List<CustomList>> getMyLists() => _guard(() async {
    final rows = await _client.rpc('get_my_custom_lists') as List<dynamic>;
    return rows
        .map((r) => CustomList.fromJson(r as Map<String, dynamic>))
        .toList();
  });

  Future<List<CustomList>> getPublicLists({int limit = 30, int offset = 0}) =>
      _guard(() async {
        final rows = await _client.rpc(
          'get_public_custom_lists',
          params: {'p_limit': limit, 'p_offset': offset},
        ) as List<dynamic>;
        return rows
            .map((r) => CustomList.fromJson(r as Map<String, dynamic>))
            .toList();
      });

  /// Own list or public list (RLS); null if not found or private.
  Future<CustomList?> getList(int listId) => _guard(() async {
    final row = await _client
        .from('custom_lists')
        .select('*, custom_list_movies(*)')
        .eq('id', listId)
        .order(
          'added_at',
          referencedTable: 'custom_list_movies',
          ascending: false,
        )
        .maybeSingle();
    if (row == null) return null;
    final owner = await _client.rpc(
      'get_custom_list_owner_name',
      params: {'p_list_id': listId},
    );
    return CustomList.fromJson(row).copyWith(ownerName: owner as String?);
  });

  Future<CustomList> createList({
    required String name,
    String description = '',
    bool isPublic = false,
  }) => _mutate(() async {
    final mine = await getMyLists();
    _check(ListRules.canCreateList(mine.length));
    _check(ListRules.validateName(name, mine.map((l) => l.name)));
    _check(ListRules.validateDescription(description));
    final row = await _client
        .from('custom_lists')
        .insert({
          'user_id': _userId,
          'name': ListRules.normalizeName(name),
          'description': description.trim(),
          'is_public': isPublic,
        })
        .select()
        .single();
    return CustomList.fromJson(row);
  });

  Future<void> updateList(
    int listId, {
    required String name,
    required String description,
    required bool isPublic,
  }) => _mutate(() async {
    final mine = await getMyLists();
    _check(
      ListRules.validateName(
        name,
        mine.where((l) => l.id != listId).map((l) => l.name),
      ),
    );
    _check(ListRules.validateDescription(description));
    final rows = await _client
        .from('custom_lists')
        .update({
          'name': ListRules.normalizeName(name),
          'description': description.trim(),
          'is_public': isPublic,
        })
        .eq('id', listId)
        .select('id');
    if (rows.isEmpty) throw const RecoException(_ownerOnly);
  });

  Future<void> deleteList(int listId) => _mutate(() async {
    final rows = await _client
        .from('custom_lists')
        .delete()
        .eq('id', listId)
        .select('id');
    if (rows.isEmpty) throw const RecoException(_ownerOnly);
  });

  Future<void> addMovie(CustomList list, ListMovie movie) => _mutate(() async {
    _check(
      ListRules.canAddMovie(
        movieCount: list.movieCount,
        alreadyInList: list.movies.any((m) => m.movieId == movie.movieId),
      ),
    );
    await _client
        .from('custom_list_movies')
        .insert(movie.toInsertJson(list.id));
  });

  Future<void> removeMovie(int listId, int movieId) => _mutate(() async {
    final rows = await _client
        .from('custom_list_movies')
        .delete()
        .eq('list_id', listId)
        .eq('tmdb_movie_id', movieId)
        .select('list_id');
    if (rows.isEmpty) throw const RecoException(_ownerOnly);
  });

  /// Ids of the user's lists that already contain [movieId].
  Future<Set<int>> myListIdsContaining(int movieId) => _guard(() async {
    final rows = await _client
        .from('custom_list_movies')
        .select('list_id, custom_lists!inner(user_id)')
        .eq('tmdb_movie_id', movieId)
        .eq('custom_lists.user_id', _userId);
    return rows.map((r) => (r['list_id'] as num).toInt()).toSet();
  });

  /// Every movie of the user's lists (recommendation signals).
  Future<List<SignalMovie>> mySignalMovies() => _guard(() async {
    final rows = await _client
        .from('custom_list_movies')
        .select(
          'tmdb_movie_id, title, genre_ids, added_at, custom_lists!inner(user_id)',
        )
        .eq('custom_lists.user_id', _userId)
        .order('added_at', ascending: false)
        .limit(500);
    return rows.map((r) {
      final m = ListMovie.fromJson(r);
      return SignalMovie(
        movieId: m.movieId,
        title: m.title,
        genreIds: m.genreIds,
        addedAt: m.addedAt ?? DateTime(2000),
      );
    }).toList();
  });

  static const String _ownerOnly = 'Only the owner can modify this list.';

  void _check(String? error) {
    if (error != null) throw RecoException(error);
  }

  /// Runs a write, then tells open screens to refresh.
  Future<T> _mutate<T>(Future<T> Function() action) async {
    final result = await _guard(action);
    ListChanges.instance.notify();
    return result;
  }

  /// Translates database errors into user-facing messages.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      final message = switch ((e.code, e.message)) {
        (_, final m) when m.contains('LIST_LIMIT_REACHED') =>
          ListRules.canCreateList(ListRules.maxLists)!,
        (_, final m) when m.contains('LIST_MOVIE_LIMIT_REACHED') =>
          'A list can contain up to ${ListRules.maxMoviesPerList} movies.',
        ('23505', final m) when m.contains('custom_list_movies') =>
          'This movie is already in the list.',
        ('23505', _) => 'You already have a list with this name.',
        ('23514', _) => 'Invalid name or description length.',
        ('42501', _) => _ownerOnly,
        _ => 'Something went wrong. Please try again.',
      };
      throw RecoException(message);
    } on AuthException {
      throw const RecoException(
        'Your session has expired. Please sign in again.',
      );
    }
  }
}
