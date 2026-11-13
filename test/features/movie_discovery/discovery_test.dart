import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movie_explorer/features/movie_discovery/presentation/controllers/discovery_controller.dart';
import 'package:movie_explorer/features/movie_discovery/presentation/pages/movie_discovery_page.dart';
import 'package:movie_explorer/features/movie_management/data/models/movie_search_query.dart';

import '../movie_management/fake_movies_repository.dart';

FakeMoviesRepository catalogue() => FakeMoviesRepository(
  movies: [
    FakeMovie(
      id: 1,
      title: 'Dune',
      year: 2021,
      rating: 8,
      popularity: 90,
      genreIds: {28},
    ),
    FakeMovie(
      id: 2,
      title: 'Amélie',
      year: 2001,
      rating: 7.9,
      popularity: 20,
      language: 'fr',
      genreIds: {35, 18},
    ),
    FakeMovie(
      id: 3,
      title: 'Dunkirk',
      year: 2017,
      rating: 7.4,
      popularity: 60,
      genreIds: {18},
    ),
    FakeMovie(
      id: 4,
      title: 'Zoolander',
      year: 2001,
      rating: 6.5,
      popularity: 30,
      genreIds: {35},
    ),
  ],
);

void main() {
  group('DiscoveryController', () {
    test('searches, filters, sorts and clears', () async {
      final c = DiscoveryController(repository: catalogue());
      await c.init();
      expect(c.movies.map((m) => m.id), [1, 3, 4, 2]);
      expect(c.genres, isNotEmpty);
      expect(c.languages, containsAll(['en', 'fr']));

      await c.setText('dun');
      expect(c.movies.map((m) => m.title), ['Dune', 'Dunkirk']);

      await c.setText('');
      await c.applyQuery(c.query.copyWith(genreIds: {35}));
      expect(c.movies.map((m) => m.id).toSet(), {2, 4});

      await c.applyQuery(c.query.copyWith(minRating: () => 7.0));
      expect(c.movies.single.id, 2);
      expect(c.query.activeFilterCount, 2);

      await c.clearFilters();
      await c.setSort(MovieSort.title);
      expect(c.movies.first.title, 'Amélie');
      expect(c.total, 4);

      await c.applyQuery(
        c.query.copyWith(yearFrom: () => 2001, yearTo: () => 2001),
      );
      expect(c.movies.map((m) => m.id), [2, 4]);

      c.movieDeleted(2);
      expect(c.movies.single.id, 4);
      expect(c.total, 1);
      c.dispose();
    });

    test('pages through large results', () async {
      final repo = FakeMoviesRepository(
        movies: [
          for (var i = 1; i <= 45; i++)
            FakeMovie(id: i, title: 'M$i', popularity: 100.0 - i),
        ],
      );
      final c = DiscoveryController(repository: repo);
      await c.search();
      expect(c.movies, hasLength(20));
      await c.loadMore();
      await c.loadMore();
      expect(c.movies, hasLength(45));
      expect(c.hasMore, isFalse);
      c.dispose();
    });
  });

  group('MovieDiscoveryPage', () {
    Future<void> pump(WidgetTester tester, FakeMoviesRepository repo) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: MovieDiscoveryPage(repository: repo)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('search box filters after typing', (tester) async {
      await pump(tester, catalogue());
      expect(find.text('4 movies'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zoo');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();

      expect(find.text('Zoolander'), findsOneWidget);
      expect(find.text('Dune'), findsNothing);
      expect(find.text('1 movie'), findsOneWidget);
    });

    testWidgets('filter sheet applies genres and shows removable chips', (
      tester,
    ) async {
      await pump(tester, catalogue());

      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Comedy'));
      await tester.tap(find.text('Show movies'));
      await tester.pumpAndSettle();

      expect(find.text('2 movies'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'Comedy'), findsOneWidget);

      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();
      expect(find.text('4 movies'), findsOneWidget);
    });

    testWidgets('deletes a movie after confirmation', (tester) async {
      final repo = catalogue();
      await pump(tester, repo);

      await tester.tap(find.byTooltip('Movie actions').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this movie?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(repo.calls, contains('delete:1'));
      expect(find.text('Dune'), findsNothing);
      expect(find.text('"Dune" deleted.'), findsOneWidget);
      expect(find.text('3 movies'), findsOneWidget);
    });

    testWidgets('empty results offer to clear filters', (tester) async {
      await pump(tester, catalogue());
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Action'));
      await tester.tap(find.widgetWithText(FilterChip, 'Comedy'));
      await tester.tap(find.text('Show movies'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'nothing here');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();

      expect(find.text('No movies match your search.'), findsOneWidget);
      expect(find.text('Clear filters'), findsOneWidget);
    });
  });
}
