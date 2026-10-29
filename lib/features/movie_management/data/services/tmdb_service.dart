import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/movie.dart';

class TmdbService {
  TmdbService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _apiKey = String.fromEnvironment('TMDB_API_KEY');
  static const String _baseUrl = 'https://api.themoviedb.org/3';

  Future<List<Movie>> getPopularMovies() async {
    _checkApiKey();

    final uri = Uri.parse('$_baseUrl/movie/popular').replace(
      queryParameters: {'api_key': _apiKey, 'language': 'en-US', 'page': '1'},
    );

    final response = await _client.get(uri);
    _checkResponse(response);

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>;

    return results
        .map((item) => Movie.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getMovieDetails(int movieId) async {
    _checkApiKey();

    final uri = Uri.parse('$_baseUrl/movie/$movieId')
        .replace(queryParameters: {'api_key': _apiKey, 'language': 'en-US'});

    final response = await _client.get(uri);
    _checkResponse(response);

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  void _checkApiKey() {
    if (_apiKey.isEmpty) {
      throw Exception(
        'TMDB API key not found. Run with '
        '--dart-define-from-file=env.json.',
      );
    }
  }

  void _checkResponse(http.Response response) {
    if (response.statusCode != 200) {
      throw Exception(
        'TMDB request failed with status ${response.statusCode}.',
      );
    }
  }

  Future<List<Movie>> searchMovies(String query) async {
    _checkApiKey();

    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return [];
    }

    final uri = Uri.parse('$_baseUrl/search/movie').replace(
      queryParameters: {
        'api_key': _apiKey,
        'language': 'en-US',
        'query': trimmedQuery,
        'page': '1',
        'include_adult': 'false',
      },
    );

    final response = await _client.get(uri);
    _checkResponse(response);

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>;

    return results
        .map((item) => Movie.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  void dispose() {
    _client.close();
  }
}
