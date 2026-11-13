import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movie_explorer/app/home_page.dart';
import 'package:movie_explorer/features/movie_management/data/services/tmdb_service.dart';
import 'package:movie_explorer/features/user_management/domain/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/movie_management/tmdb_fixtures.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  User? get currentUser => null;

  @override
  Future<void> signOut() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// TMDB stub: every list returns two movies without images so no network
/// image loading happens during the test.
TmdbService fakeTmdbService({int status = 200}) => TmdbService(
  apiKey: 'test',
  client: fakeTmdb((request) {
    final slug = request.url.pathSegments.last;
    final ids = slug.length; // distinct ids per list
    return (
      status,
      {
        'page': 1,
        'total_pages': 1,
        'results': [
          for (final id in [ids, ids + 100])
            {...movieJson(id), 'poster_path': null, 'title': '$slug $id'},
        ],
      },
    );
  }),
);

void main() {
  testWidgets('Movie Explorer home screen loads', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          authService: FakeAuthRepository(),
          tmdbService: fakeTmdbService(),
        ),
      ),
    );

    expect(find.text('Movie Explorer'), findsOneWidget);
    expect(find.text('YOUR NEXT MOVIE NIGHT'), findsOneWidget);
  });

  testWidgets('home shows the featured movie and the four catalogue lists', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          authService: FakeAuthRepository(),
          tmdbService: fakeTmdbService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('POPULAR RIGHT NOW'), findsOneWidget);
    // Featured card + first card of the popular row.
    expect(find.text('popular 7'), findsNWidgets(2));
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

  testWidgets('home shows a retry action when TMDB fails', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          authService: FakeAuthRepository(),
          tmdbService: fakeTmdbService(status: 500),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load movies from TMDB.'), findsOneWidget);
    expect(find.text('Try again'), findsWidgets);
  });
}
