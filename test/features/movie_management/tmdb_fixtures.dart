import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> movieJson(int id, {String? releaseDate}) => {
  'id': id,
  'title': 'Movie $id',
  'overview': 'Overview $id',
  'poster_path': '/poster$id.jpg',
  'backdrop_path': null,
  'vote_average': 7.25,
  'vote_count': 1200,
  'release_date': releaseDate ?? '2024-05-0${id % 9 + 1}',
  'original_language': 'en',
};

Map<String, dynamic> pageJson(
  List<int> ids, {
  int page = 1,
  int totalPages = 3,
}) => {
  'page': page,
  'total_pages': totalPages,
  'results': [for (final id in ids) movieJson(id)],
};

/// Fake TMDB backend. [handler] receives each request and returns
/// `(statusCode, jsonBody)`.
MockClient fakeTmdb((int, Object) Function(http.Request request) handler) {
  return MockClient((request) async {
    final (status, body) = handler(request);
    return http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );
  });
}
