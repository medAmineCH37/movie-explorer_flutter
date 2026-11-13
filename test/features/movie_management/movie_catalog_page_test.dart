import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movie_explorer/features/movie_management/data/models/movie_category.dart';
import 'package:movie_explorer/features/movie_management/data/services/tmdb_service.dart';
import 'package:movie_explorer/features/movie_management/presentation/pages/movie_catalog_page.dart';

import 'tmdb_fixtures.dart';

void main() {
  testWidgets('catalogue opens on the requested list and switches tabs', (
    tester,
  ) async {
    final requested = <String>[];
    final service = TmdbService(
      apiKey: 'k',
      client: fakeTmdb((request) {
        final slug = request.url.pathSegments.last;
        requested.add(slug);
        final base = slug == 'upcoming' ? 500 : 100;
        return (
          200,
          {
            'page': 1,
            'total_pages': 1,
            'results': [
              for (final id in [base + 1, base + 2])
                {...movieJson(id), 'poster_path': null, 'title': '$slug $id'},
            ],
          },
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MovieCatalogPage(
          initialCategory: MovieCategory.topRated,
          tmdbService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requested, ['top_rated']);
    expect(find.text('top_rated 101'), findsOneWidget);
    expect(find.text("You've reached the end of this list."), findsOneWidget);

    await tester.tap(find.text('Upcoming'));
    await tester.pumpAndSettle();

    expect(requested, contains('upcoming'));
    expect(find.text('upcoming 501'), findsOneWidget);
  });

  testWidgets('catalogue shows an error with retry', (tester) async {
    var fail = true;
    final service = TmdbService(
      apiKey: 'k',
      client: fakeTmdb(
        (_) => fail ? (500, {}) : (200, pageJson([1], totalPages: 1)),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: MovieCatalogPage(tmdbService: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not load popular movies.'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Movie 1'), findsOneWidget);
  });
}
