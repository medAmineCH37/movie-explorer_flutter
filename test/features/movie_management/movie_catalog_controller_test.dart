import 'package:flutter_test/flutter_test.dart';
import 'package:movie_explorer/features/movie_management/data/models/movie_category.dart';
import 'package:movie_explorer/features/movie_management/domain/repositories/movies_repository.dart';
import 'package:movie_explorer/features/movie_management/presentation/controllers/movie_catalog_controller.dart';

import 'fake_movies_repository.dart';

void main() {
  FakeMoviesRepository repoWith(int count) => FakeMoviesRepository(
    movies: [
      for (var i = 1; i <= count; i++)
        FakeMovie(id: i, title: 'Movie $i', popularity: 1000.0 - i),
    ],
  );

  test('loads pages until the last one', () async {
    final repo = repoWith(25);
    final c = MovieCatalogController(
      category: MovieCategory.popular,
      repository: repo,
    );

    await c.loadInitial();
    expect(c.movies, hasLength(20));
    expect(c.movies.first.id, 1);
    expect(c.hasMore, isTrue);

    await c.loadMore();
    expect(c.movies, hasLength(25));
    expect(c.hasMore, isFalse);

    await c.loadMore();
    expect(repo.calls, ['search:popular:1', 'search:popular:2']);
    c.dispose();
  });

  test('exposes a readable error', () async {
    final repo = repoWith(3)..failWith = const MovieException('Offline');
    final c = MovieCatalogController(
      category: MovieCategory.upcoming,
      repository: repo,
    );
    await c.loadInitial();
    expect(c.error, 'Could not load upcoming movies.');
    expect(c.isLoading, isFalse);
    c.dispose();
  });

  test('keeps loaded movies when a later page fails', () async {
    final repo = repoWith(30);
    final c = MovieCatalogController(
      category: MovieCategory.popular,
      repository: repo,
    );
    await c.loadInitial();
    repo.failWith = const MovieException('Offline');
    await c.loadMore();
    expect(c.movies, hasLength(20));
    expect(c.loadMoreError, isNotNull);
    c.dispose();
  });
}
