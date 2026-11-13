import 'package:flutter_test/flutter_test.dart';
import 'package:movie_explorer/features/movie_management/data/models/movie_category.dart';
import 'package:movie_explorer/features/movie_management/data/services/tmdb_service.dart';
import 'package:movie_explorer/features/movie_management/presentation/controllers/movie_catalog_controller.dart';
import 'package:movie_explorer/features/movie_management/presentation/movie_formatters.dart';

import 'tmdb_fixtures.dart';

void main() {
  group('MovieCatalogController', () {
    test(
      'loads pages, removes duplicates and stops at the last page',
      () async {
        final pages = {
          '1': pageJson([1, 2, 3], page: 1, totalPages: 2),
          '2': pageJson([3, 4], page: 2, totalPages: 2),
        };
        final controller = MovieCatalogController(
          category: MovieCategory.topRated,
          tmdbService: TmdbService(
            apiKey: 'k',
            client: fakeTmdb(
              (r) => (200, pages[r.url.queryParameters['page']]!),
            ),
          ),
        );

        await controller.loadInitial();
        expect(controller.movies.map((m) => m.id), [1, 2, 3]);
        expect(controller.hasMore, isTrue);

        await controller.loadMore();
        expect(controller.movies.map((m) => m.id), [1, 2, 3, 4]);
        expect(controller.hasMore, isFalse);

        await controller.loadMore();
        expect(controller.movies, hasLength(4));
        controller.dispose();
      },
    );

    test('exposes a readable error when the first page fails', () async {
      final controller = MovieCatalogController(
        category: MovieCategory.upcoming,
        tmdbService: TmdbService(
          apiKey: 'k',
          client: fakeTmdb((_) => (500, {})),
        ),
      );

      await controller.loadInitial();

      expect(controller.error, 'Could not load upcoming movies.');
      expect(controller.isLoading, isFalse);
      expect(controller.movies, isEmpty);
      controller.dispose();
    });

    test('keeps loaded movies when a later page fails', () async {
      var calls = 0;
      final controller = MovieCatalogController(
        category: MovieCategory.popular,
        tmdbService: TmdbService(
          apiKey: 'k',
          client: fakeTmdb((_) {
            calls++;
            return calls == 1 ? (200, pageJson([1, 2])) : (503, {});
          }),
        ),
      );

      await controller.loadInitial();
      await controller.loadMore();

      expect(controller.movies, hasLength(2));
      expect(controller.loadMoreError, isNotNull);
      expect(controller.isLoadingMore, isFalse);
      controller.dispose();
    });
  });

  group('MovieFormatters', () {
    test('formats runtime, counts and dates', () {
      expect(MovieFormatters.runtime(148), '2h 28m');
      expect(MovieFormatters.runtime(45), '45m');
      expect(MovieFormatters.runtime(120), '2h');
      expect(MovieFormatters.runtime(0), isNull);
      expect(MovieFormatters.compactCount(999), '999');
      expect(MovieFormatters.compactCount(12345), '12.3k');
      expect(MovieFormatters.compactCount(2000000), '2M');
      expect(MovieFormatters.date('2024-03-01'), '1 Mar 2024');
      expect(MovieFormatters.date('soon'), 'soon');
    });
  });
}
