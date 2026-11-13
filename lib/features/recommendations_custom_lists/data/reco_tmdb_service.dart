import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/models/tmdb_candidate.dart';

/// TMDB endpoints used by Module 6 (keeps `genre_ids` for scoring).
class RecoTmdbService {
  RecoTmdbService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _apiKey = String.fromEnvironment('TMDB_API_KEY');
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static Map<int, String>? _genreNames;

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String> params = const {},
  ]) async {
    if (_apiKey.isEmpty) {
      throw const RecoException(
        'TMDB API key not found. Run with --dart-define-from-file=env.json.',
      );
    }
    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: {'api_key': _apiKey, 'language': 'en-US', ...params},
    );
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw RecoException(
        'Movies are unavailable (TMDB ${response.statusCode}).',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<TmdbCandidate>> _page(
    String path, [
    Map<String, String> params = const {},
  ]) async {
    final data = await _get(path, params);
    return (data['results'] as List<dynamic>)
        .map((m) => TmdbCandidate.fromJson(m as Map<String, dynamic>))
        .where((m) => m.posterPath != null)
        .toList();
  }

  Future<List<TmdbCandidate>> trending() => _page('/trending/movie/week');

  Future<List<TmdbCandidate>> recommendations(int movieId) =>
      _page('/movie/$movieId/recommendations');

  /// [anyOf]: true = OR between genres ("|"), false = AND (",").
  Future<List<TmdbCandidate>> discoverByGenres(
    List<int> genreIds, {
    bool anyOf = true,
  }) => _page('/discover/movie', {
    'with_genres': genreIds.join(anyOf ? '|' : ','),
    'sort_by': 'popularity.desc',
    'vote_count.gte': '100',
    'include_adult': 'false',
  });

  Future<List<TmdbCandidate>> search(String query) {
    final q = query.trim();
    if (q.isEmpty) return Future.value(const []);
    return _page('/search/movie', {'query': q, 'include_adult': 'false'});
  }

  Future<TmdbCandidate> details(int movieId) async =>
      TmdbCandidate.fromJson(await _get('/movie/$movieId'));

  Future<Map<int, String>> genreNames() async {
    final cached = _genreNames;
    if (cached != null) return cached;
    final data = await _get('/genre/movie/list');
    final names = {
      for (final g in data['genres'] as List<dynamic>)
        (g as Map<String, dynamic>)['id'] as int: g['name'] as String,
    };
    return _genreNames = names;
  }

  void dispose() => _client.close();
}

class RecoException implements Exception {
  const RecoException(this.message);
  final String message;

  @override
  String toString() => message;
}
