import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movie_explorer/app/home_page.dart';
import 'package:movie_explorer/features/movie_management/domain/repositories/movies_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/movie_management/fake_movies_repository.dart';

FakeMoviesRepository fakeMovies({bool fail = false}) {
  final repo = FakeMoviesRepository(
    movies: [
      FakeMovie(id: 7, title: 'Top Movie', popularity: 99),
      FakeMovie(id: 8, title: 'Second Movie', popularity: 50),
    ],
  );
  if (fail) repo.failWith = const MovieException('Offline');
  return repo;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://supabase.co',
      publishableKey: 'dummy-anon-key',
    );
  });

  testWidgets('Movie Explorer home screen loads', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: HomePage(moviesRepository: fakeMovies())),
      ),
    );

    expect(find.text('Movie Explorer'), findsOneWidget);
    expect(find.text('YOUR NEXT MOVIE NIGHT'), findsOneWidget);
  });

  testWidgets('home shows the featured movie and the four catalogue lists', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: HomePage(moviesRepository: fakeMovies())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('POPULAR RIGHT NOW'), findsOneWidget);
    // Featured card + first card of the popular row.
    expect(find.text('Top Movie'), findsNWidgets(2));
    expect(find.text('Popular'), findsOneWidget);
    expect(find.text('See all'), findsWidgets);

    for (final title in ['Top rated', 'Now playing', 'Upcoming']) {
      await tester.scrollUntilVisible(
        find.text(title),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(title), findsOneWidget);
    }
  });

  testWidgets('home shows a retry action when loading fails', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: HomePage(moviesRepository: fakeMovies(fail: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load movies.'), findsOneWidget);
    expect(find.text('Try again'), findsWidgets);
  });
}
