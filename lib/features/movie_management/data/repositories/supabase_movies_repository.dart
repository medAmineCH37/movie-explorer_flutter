import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/repositories/movies_repository.dart';
import '../models/genre.dart';
import '../models/movie.dart';
import '../models/movie_category.dart';
import '../models/movie_details.dart';
import '../models/movie_draft.dart';
import '../models/movie_page.dart';
import '../models/movie_search_query.dart';

/// [MoviesRepository] backed by the Supabase tables `movies`, `genres`,
/// `movie_genres` and `movie_credits`. Rules (validation, access) are
/// enforced in the database; errors become [MovieException]s.
class SupabaseMoviesRepository extends MoviesRepository {
  SupabaseMoviesRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _signInMessage = 'Sign in to manage movies.';
  static const _networkMessage =
      'Connection failed. Check your network and try again.';

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Future<MoviePage> getCategory(
    MovieCategory category, {
    int page = 1,
    int pageSize = 20,
  }) => search(
    MovieSearchQuery(category: category),
    page: page,
    pageSize: pageSize,
  );

  @override
  Future<MoviePage> search(
    MovieSearchQuery query, {
    int page = 1,
    int pageSize = 20,
  }) => _guard(() async {
    final result = await _client.rpc<dynamic>(
      'search_movies',
      params: query.toParams(page: page, pageSize: pageSize),
    );
    final rows = (result as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    return MoviePage.fromRows(rows, page: page, pageSize: pageSize);
  });

  @override
  Future<MovieDetails?> getMovie(int id) => _guard(() async {
    final row = await _client
        .from('movies')
        .select(MovieDetails.selectColumns)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : MovieDetails.fromJson(row);
  });

  @override
  Future<Map<int, Movie>> getMoviesByIds(Iterable<int> ids) => _guard(() async {
    final unique = ids.toSet().toList();
    if (unique.isEmpty) return {};
    final rows = await _client
        .from('movies')
        .select(
          'id, title, overview, release_date, runtime, original_language, '
          'poster_url, backdrop_url, vote_average, vote_count, '
          'movie_genres(genres(name))',
        )
        .inFilter('id', unique);
    return {
      for (final row in rows) (row['id'] as num).toInt(): Movie.fromJson(row),
    };
  });

  @override
  Future<List<Genre>> getGenres() => _guard(() async {
    final rows = await _client.from('genres').select('id, name').order('name');
    return rows.map(Genre.fromJson).toList();
  });

  @override
  Future<List<String>> getLanguages() => _guard(() async {
    final result = await _client.rpc<dynamic>('movie_languages');
    return [
      for (final row in result as List<dynamic>) (row as Map)['code'] as String,
    ];
  });

  @override
  Future<int> createMovie(MovieDraft draft) => _guard(() async {
    _requireSignIn();
    _validate(draft);
    final id = await _client.rpc<dynamic>(
      'save_movie',
      params: draft.toRpcParams(null),
    );
    return (id as num).toInt();
  });

  @override
  Future<void> updateMovie(int id, MovieDraft draft) => _guard(() async {
    _requireSignIn();
    _validate(draft);
    await _client.rpc<dynamic>('save_movie', params: draft.toRpcParams(id));
  });

  @override
  Future<void> deleteMovie(int id) => _guard(() async {
    _requireSignIn();
    final rows = await _client
        .from('movies')
        .delete()
        .eq('id', id)
        .select('id');
    if (rows.isEmpty) {
      throw const MovieException('This movie no longer exists.');
    }
  });

  // -------------------------------------------------------------------------

  void _requireSignIn() {
    if (currentUserId == null) {
      throw const MovieException(_signInMessage, requiresSignIn: true);
    }
  }

  void _validate(MovieDraft draft) {
    final errors = draft.validate();
    if (errors.isNotEmpty) throw MovieException(errors.values.first);
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on MovieException {
      rethrow;
    } on PostgrestException catch (e) {
      throw MovieException(_message(e), requiresSignIn: e.code == '42501');
    } on AuthException {
      throw const MovieException(_signInMessage, requiresSignIn: true);
    } on http.ClientException {
      throw const MovieException(_networkMessage);
    } on TimeoutException {
      throw const MovieException(_networkMessage);
    }
  }

  static String _message(PostgrestException e) {
    switch (e.code) {
      case '42501':
        return _signInMessage;
      case 'P0002':
        return 'This movie no longer exists.';
      case '23514':
      case '22023':
      case '22P02':
      case '22003':
      case '22008':
        return 'Some values are not valid. Check the form and try again.';
      case '23503':
        return 'Unknown genre.';
      case 'PGRST301':
      case 'PGRST303':
        return 'Your session expired. Sign in again.';
    }
    return 'Something went wrong. Please try again.';
  }
}
