import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movie_explorer/app/home_page.dart';
import 'package:movie_explorer/features/movie_management/data/services/tmdb_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/movie_management/tmdb_fixtures.dart';

/// TMDB stub: every list returns two movies without images so no network
/// image loading happens during the test.
TmdbService fakeTmdbService({int status = 200}) => TmdbService(
  apiKey: 'test',
  client: fakeTmdb((request) {
    final slug = request.url.pathSegments.last;
    final ids = slug.length;
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
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://supabase.co',
      publishableKey: 'dummy-anon-key',
    );
  });

  testWidgets('CinéHub home screen loads', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: HomePage(tmdbService: fakeTmdbService())),
      ),
    );

    // Brand logo: "Ciné" + "Hub".
    expect(find.text('Ciné'), findsOneWidget);
    expect(find.text('Hub'), findsOneWidget);
  });

  testWidgets('home shows the featured movie and the four catalogue lists', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: HomePage(tmdbService: fakeTmdbService())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('POPULAR RIGHT NOW'), findsOneWidget);
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
      ProviderScope(
        child: MaterialApp(
          home: HomePage(tmdbService: fakeTmdbService(status: 500)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load movies from TMDB.'), findsOneWidget);
    expect(find.text('Try again'), findsWidgets);
  });
}
