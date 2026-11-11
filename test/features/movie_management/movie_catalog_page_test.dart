import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movie_explorer/features/movie_management/data/models/movie_category.dart';
import 'package:movie_explorer/features/movie_management/domain/repositories/movies_repository.dart';
import 'package:movie_explorer/features/movie_management/presentation/pages/movie_catalog_page.dart';

import 'fake_movies_repository.dart';

void main() {
  testWidgets('catalogue opens on the requested list and switches tabs', (
    tester,
  ) async {
    final repo = FakeMoviesRepository(
      movies: [
        FakeMovie(id: 1, title: 'Alpha'),
        FakeMovie(id: 2, title: 'Beta'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MovieCatalogPage(
          initialCategory: MovieCategory.topRated,
          repository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.calls, ['search:top_rated:1']);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text("You've reached the end of this list."), findsOneWidget);
    expect(find.text('Add movie'), findsOneWidget);

    await tester.tap(find.text('Upcoming'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('search:upcoming:1'));
  });

  testWidgets('catalogue shows an error with retry', (tester) async {
    final repo = FakeMoviesRepository(movies: [FakeMovie(id: 1, title: 'A')])
      ..failWith = const MovieException('Offline');

    await tester.pumpWidget(
      MaterialApp(home: MovieCatalogPage(repository: repo)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not load popular movies.'), findsOneWidget);

    repo.failWith = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('adding a movie while signed out asks to sign in', (
    tester,
  ) async {
    final repo = FakeMoviesRepository(userId: null);
    await tester.pumpWidget(
      MaterialApp(home: MovieCatalogPage(repository: repo)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add movie'));
    await tester.pump();
    expect(find.text('Sign in to manage movies.'), findsOneWidget);
  });
}
