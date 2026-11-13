import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:movie_explorer/features/movie_management/presentation/pages/movie_form_page.dart';

import 'fake_movies_repository.dart';

/// Router with a launcher page, the form routes and a stub details page.
GoRouter routerFor(FakeMoviesRepository repo, {required String start}) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final saved = await context.push<bool>(start);
                if (context.mounted && saved == true) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('SAVED')));
                }
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/movies/new',
        builder: (_, _) => MovieFormPage(repository: repo),
      ),
      GoRoute(
        path: '/movie/:id',
        builder: (_, state) =>
            Scaffold(body: Text('Details ${state.pathParameters['id']}')),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, state) => MovieFormPage(
              movieId: int.parse(state.pathParameters['id']!),
              repository: repo,
            ),
          ),
        ],
      ),
    ],
  );
}

Future<void> open(WidgetTester tester, GoRouter router) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Finder field(String label) => find.widgetWithText(TextFormField, label);

/// Scrolls [finder] into view (all form fields are built).
Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String label, String text) async {
  await reveal(tester, field(label));
  await tester.enterText(field(label), text);
}

Future<void> save(WidgetTester tester) async {
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('creates a movie and opens its page', (tester) async {
    final repo = FakeMoviesRepository();
    await open(tester, routerFor(repo, start: '/movies/new'));

    expect(find.text('Add a movie'), findsOneWidget);

    // Invalid: missing title, bad runtime, http poster.
    await enter(tester, 'Runtime', '0');
    await enter(tester, 'Poster image URL', 'http://x.test/p.jpg');
    await save(tester);
    expect(repo.calls, isNot(contains('create')));
    expect(find.text('Fix the highlighted fields first.'), findsOneWidget);
    expect(find.text('Use an https:// image link.'), findsOneWidget);
    expect(find.text('Enter minutes between 1 and 1000.'), findsOneWidget);
    expect(find.text('The title is required.'), findsOneWidget);

    await enter(tester, 'Title *', 'Night Train');
    await enter(tester, 'Runtime', '104');
    await enter(tester, 'Poster image URL', '');
    await enter(tester, 'Directors', 'Ann Lee, Bo Ray');
    await reveal(tester, find.widgetWithText(FilterChip, 'Comedy'));
    await tester.tap(find.widgetWithText(FilterChip, 'Comedy'));
    await save(tester);

    expect(repo.calls, contains('create'));
    expect(repo.lastSaved?.genreIds, {35});
    expect(repo.lastSaved?.directorNames, ['Ann Lee', 'Bo Ray']);
    expect(repo.movies.single.title, 'Night Train');
    expect(find.text('Details 100000000'), findsOneWidget);
  });

  testWidgets('edits an existing movie and returns true', (tester) async {
    final repo = FakeMoviesRepository(
      movies: [
        FakeMovie(id: 7, title: 'Old title', genreIds: {18})
          ..directors = ['Jane Roe'],
      ],
    );
    await open(tester, routerFor(repo, start: '/movie/7/edit'));

    expect(find.text('Edit movie'), findsOneWidget);
    expect(find.text('Old title'), findsOneWidget);
    expect(find.text('Jane Roe'), findsOneWidget);

    await enter(tester, 'Title *', 'New title');
    await save(tester);

    expect(repo.calls, contains('update:7'));
    expect(repo.movies.single.title, 'New title');
    expect(find.text('SAVED'), findsOneWidget);
  });

  testWidgets('shows an error when the movie was deleted', (tester) async {
    final repo = FakeMoviesRepository();
    await open(tester, routerFor(repo, start: '/movie/9/edit'));
    expect(find.text('This movie no longer exists.'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
  });
}
