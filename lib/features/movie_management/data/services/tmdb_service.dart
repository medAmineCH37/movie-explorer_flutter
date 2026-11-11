import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/movie.dart';
import '../models/movie_category.dart';
import '../models/movie_details.dart';
import '../models/movie_page.dart';

/// Thrown when TMDB answers with a non-200 status.
class TmdbException implements Exception {
  const TmdbException(this.statusCode);

  final int statusCode;

  bool get isNotFound => statusCode == 404;

  @override
  String toString() => 'TMDB request failed with status $statusCode.';
}

class TmdbService {
  TmdbService({http.Client? client, String? apiKey})
    : _client = client ?? http.Client(),
      _apiKey = apiKey ?? _envApiKey;

  final http.Client _client;
  final String _apiKey;

  static const String _envApiKey = String.fromEnvironment('TMDB_API_KEY');
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _language = 'en-US';

  Future<List<Movie>> getPopularMovies() async {
    final page = await getMovies(MovieCategory.popular);
    return page.movies;
  }

  /// One page of a TMDB list (popular, top rated, now playing, upcoming).
  Future<MoviePage> getMovies(MovieCategory category, {int page = 1}) async {
    final data = await _get('/movie/${category.slug}', {
      'page': '${page.clamp(1, MoviePage.maxTmdbPage)}',
    });
    return MoviePage.fromJson(data);
  }

  /// Raw TMDB details payload (kept for modules that parse it themselves).
  Future<Map<String, dynamic>> getMovieDetails(int movieId) {
    return _get('/movie/$movieId');
  }

  /// Details with cast, crew and videos in a single request.
  Future<MovieDetails> getFullMovieDetails(int movieId) async {
    final data = await _get('/movie/$movieId', {
      'append_to_response': 'credits,videos',
      'include_video_language': 'en,null',
    });
    return MovieDetails.fromJson(data);
  }

  Future<List<Movie>> searchMovies(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      _checkApiKey();
      return [];
    }

    final data = await _get('/search/movie', {
      'query': trimmedQuery,
      'page': '1',
      'include_adult': 'false',
    });
    return MoviePage.fromJson(data).movies;
  }

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String> query = const {},
  ]) async {
    _checkApiKey();

    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: {'api_key': _apiKey, 'language': _language, ...query},
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw TmdbException(response.statusCode);
    }
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

  void dispose() {
    _client.close();
  }
}
