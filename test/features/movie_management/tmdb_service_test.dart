import 'package:flutter_test/flutter_test.dart';
import 'package:movie_explorer/features/movie_management/data/models/movie_category.dart';
import 'package:movie_explorer/features/movie_management/data/models/movie_details.dart';
import 'package:movie_explorer/features/movie_management/data/services/tmdb_service.dart';

import 'tmdb_fixtures.dart';

void main() {
  group('TmdbService', () {
    test('requests each category endpoint with page and key', () async {
      final requested = <Uri>[];
      final service = TmdbService(
        apiKey: 'test-key',
        client: fakeTmdb((request) {
          requested.add(request.url);
          return (200, pageJson([1, 2], page: 2, totalPages: 2));
        }),
      );

      for (final category in MovieCategory.values) {
        final page = await service.getMovies(category, page: 2);
        expect(page.movies.map((m) => m.id), [1, 2]);
        expect(page.hasMore, isFalse);
      }

      expect(requested.map((u) => u.path), [
        '/3/movie/popular',
        '/3/movie/top_rated',
        '/3/movie/now_playing',
        '/3/movie/upcoming',
      ]);
      expect(requested.first.queryParameters['page'], '2');
      expect(requested.first.queryParameters['api_key'], 'test-key');
    });

    test('loads credits and videos in one details request', () async {
      late Uri requested;
      final service = TmdbService(
        apiKey: 'k',
        client: fakeTmdb((request) {
          requested = request.url;
          return (
            200,
            {
              ...movieJson(7),
              'runtime': 148,
              'tagline': ' Dream big. ',
              'status': 'Released',
              'genres': [
                {'id': 1, 'name': 'Sci-Fi'},
              ],
              'spoken_languages': [
                {'iso_639_1': 'en', 'english_name': 'English'},
              ],
              'credits': {
                'cast': [
                  for (var i = 0; i < 20; i++)
                    {'id': i, 'name': 'Actor $i', 'character': 'Role $i'},
                ],
                'crew': [
                  {'name': 'Jane Doe', 'job': 'Director'},
                  {'name': 'Jane Doe', 'job': 'Director'},
                  {'name': 'Sam Roe', 'job': 'Producer'},
                  {'name': 'Max Poe', 'job': 'Director'},
                ],
              },
              'videos': {
                'results': [
                  {
                    'key': 'clip',
                    'site': 'YouTube',
                    'type': 'Clip',
                    'official': true,
                  },
                  {
                    'key': 'teaser',
                    'site': 'YouTube',
                    'type': 'Teaser',
                    'official': true,
                  },
                  {
                    'key': 'fan',
                    'site': 'YouTube',
                    'type': 'Trailer',
                    'official': false,
                  },
                  {
                    'key': 'vimeo',
                    'site': 'Vimeo',
                    'type': 'Trailer',
                    'official': true,
                  },
                ],
              },
            },
          );
        }),
      );

      final details = await service.getFullMovieDetails(7);

      expect(requested.path, '/3/movie/7');
      expect(requested.queryParameters['append_to_response'], 'credits,videos');
      expect(details.movie.runtime, 148);
      expect(details.movie.genres, ['Sci-Fi']);
      expect(details.tagline, 'Dream big.');
      expect(details.languageName, 'English');
      expect(details.cast, hasLength(MovieDetails.maxCast));
      expect(details.directors, ['Jane Doe', 'Max Poe']);
      expect(details.trailer?.key, 'fan');
    });

    test('throws TmdbException with the status code', () async {
      final service = TmdbService(
        apiKey: 'k',
        client: fakeTmdb((_) => (404, {'status_message': 'nope'})),
      );

      await expectLater(
        service.getFullMovieDetails(1),
        throwsA(
          isA<TmdbException>().having((e) => e.isNotFound, 'isNotFound', true),
        ),
      );
    });

    test('fails fast without an API key', () async {
      var called = false;
      final service = TmdbService(
        apiKey: '',
        client: fakeTmdb((_) {
          called = true;
          return (200, pageJson([]));
        }),
      );

      await expectLater(service.getPopularMovies(), throwsException);
      expect(called, isFalse);
    });
  });

  group('MovieVideo.pickTrailer', () {
    MovieVideo video(String key, String type, {bool official = false}) =>
        MovieVideo(
          key: key,
          name: key,
          site: 'YouTube',
          type: type,
          official: official,
        );

    test('prefers official trailers, then trailers, then teasers', () {
      expect(
        MovieVideo.pickTrailer([
          video('t', 'Teaser', official: true),
          video('a', 'Trailer'),
          video('b', 'Trailer', official: true),
        ])?.key,
        'b',
      );
      expect(
        MovieVideo.pickTrailer([video('t', 'Teaser'), video('c', 'Clip')])?.key,
        't',
      );
    });

    test('returns null when nothing is playable', () {
      expect(MovieVideo.pickTrailer([video('c', 'Featurette')]), isNull);
      expect(MovieVideo.pickTrailer(const []), isNull);
    });
  });
}
