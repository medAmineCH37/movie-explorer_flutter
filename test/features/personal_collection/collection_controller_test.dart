
import 'package:flutter_test/flutter_test.dart';

import 'package:movie_explorer/features/movie_management/data/models/movie.dart';
import 'package:movie_explorer/features/personal_collection/domain/repositories/collection_repository.dart';
import 'package:movie_explorer/features/personal_collection/data/services/collection_movie_service.dart';
import 'package:movie_explorer/features/personal_collection/presentation/controllers/collection_controller.dart';

class FakeCollectionRepository implements CollectionRepository {
  List<int> favoriteIds = [];
  List<int> watchlistIds = [];

  bool shouldThrow = false;

  @override
  Future<List<int>> getFavorites() async {
    if (shouldThrow) throw Exception('Repository error');
    return favoriteIds;
  }

  @override
  Future<List<int>> getWatchlist() async {
    if (shouldThrow) throw Exception('Repository error');
    return watchlistIds;
  }

  @override
  Future<void> addFavorite(int movieId) async {
    if (shouldThrow) throw Exception('Repository error');
    if (!favoriteIds.contains(movieId)) {
      favoriteIds.add(movieId);
    }
  }

  @override
  Future<void> removeFavorite(int movieId) async {
    if (shouldThrow) throw Exception('Repository error');
    favoriteIds.remove(movieId);
  }

  @override
  Future<void> addToWatchlist(int movieId) async {
    if (shouldThrow) throw Exception('Repository error');
    if (!watchlistIds.contains(movieId)) {
      watchlistIds.add(movieId);
    }
  }

  @override
  Future<void> removeFromWatchlist(int movieId) async {
    if (shouldThrow) throw Exception('Repository error');
    watchlistIds.remove(movieId);
  }

  @override
  Future<bool> isFavorite(int movieId) async {
    return favoriteIds.contains(movieId);
  }

  @override
  Future<bool> isInWatchlist(int movieId) async {
    return watchlistIds.contains(movieId);
  }
}

class FakeCollectionMovieService implements CollectionMovieService {
  @override
  Future<List<Movie>> getMoviesByIds(List<int> movieIds) async {
    return movieIds
        .map(
          (id) => Movie(
            id: id,
            title: 'Movie $id',
            overview: 'Test overview',
            posterPath: null,
            backdropPath: null,
            voteAverage: 8.0,
            releaseDate: '2025-01-01',
          ),
        )
        .toList();
  }

  @override
  void dispose() {}
}

void main() {
  late FakeCollectionRepository repository;
  late FakeCollectionMovieService movieService;
  late CollectionController controller;

  setUp(() {
    repository = FakeCollectionRepository();
    movieService = FakeCollectionMovieService();

    controller = CollectionController(
      repository: repository,
      movieService: movieService,
    );
  });

  tearDown(() {
    controller.dispose();
  });

  group('CollectionController', () {
    test('loads favorites successfully', () async {
      repository.favoriteIds = [1, 2];

      await controller.loadFavorites();

      expect(controller.favorites.length, 2);
      expect(controller.favorites[0].id, 1);
      expect(controller.favorites[1].id, 2);
      expect(controller.isFavoritesLoading, false);
      expect(controller.favoritesError, isNull);
    });

    test('loads watchlist successfully', () async {
      repository.watchlistIds = [3, 4];

      await controller.loadWatchlist();

      expect(controller.watchlist.length, 2);
      expect(controller.watchlist[0].id, 3);
      expect(controller.watchlist[1].id, 4);
      expect(controller.isWatchlistLoading, false);
      expect(controller.watchlistError, isNull);
    });

    test('adds a movie to favorites', () async {
      await controller.addFavorite(10);

      expect(repository.favoriteIds, contains(10));
      expect(controller.favorites.map((movie) => movie.id), contains(10));
    });

    test('removes a movie from favorites', () async {
      repository.favoriteIds = [10];

      await controller.removeFavorite(10);

      expect(repository.favoriteIds, isNot(contains(10)));
      expect(controller.favorites, isEmpty);
    });

    test('adds a movie to watchlist', () async {
      await controller.addToWatchlist(20);

      expect(repository.watchlistIds, contains(20));
      expect(controller.watchlist.map((movie) => movie.id), contains(20));
    });

    test('removes a movie from watchlist', () async {
      repository.watchlistIds = [20];

      await controller.removeFromWatchlist(20);

      expect(repository.watchlistIds, isNot(contains(20)));
      expect(controller.watchlist, isEmpty);
    });

    test('handles favorites loading errors', () async {
      repository.shouldThrow = true;

      await controller.loadFavorites();

      expect(controller.favoritesError, isNotNull);
      expect(controller.isFavoritesLoading, false);
    });

    test('handles watchlist loading errors', () async {
      repository.shouldThrow = true;

      await controller.loadWatchlist();

      expect(controller.watchlistError, isNotNull);
      expect(controller.isWatchlistLoading, false);
    });
  });
}
