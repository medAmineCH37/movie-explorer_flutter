import 'package:flutter_test/flutter_test.dart';
import 'package:movie_explorer/features/movie_management/data/models/movie.dart';
import 'package:movie_explorer/features/ratings_reviews/domain/models/review_sort.dart';
import 'package:movie_explorer/features/ratings_reviews/domain/repositories/reviews_repository.dart';
import 'package:movie_explorer/features/ratings_reviews/presentation/controllers/all_reviews_controller.dart';
import 'package:movie_explorer/features/ratings_reviews/presentation/controllers/movie_reviews_controller.dart';
import 'package:movie_explorer/features/ratings_reviews/presentation/controllers/my_ratings_controller.dart';

import 'fake_reviews_repository.dart';

void main() {
  group('MovieReviewsController', () {
    late FakeReviewsRepository repo;

    setUp(() {
      repo = FakeReviewsRepository()
        ..ratings[('a', 1)] = 5
        ..ratings[('b', 1)] = 2
        ..reviews.addAll([
          review(1, userId: 'a', likes: 3),
          review(2, userId: 'b'),
          review(3, userId: me),
          review(4, userId: 'c'),
          review(5, userId: 'd'),
          review(6, movieId: 2, userId: 'e'),
        ]);
    });

    test('loads summary and composes highlights', () async {
      final c = MovieReviewsController(movieId: 1, repository: repo);
      await c.load();

      expect(c.error, isNull);
      expect(c.summary.count, 2);
      expect(c.summary.average, 3.5);
      expect(c.reviewCount, 5);
      expect(c.myReview?.id, 3);
      expect(c.highlights.top?.id, 1);
      expect(c.highlights.latest.map((r) => r.id), [5, 4, 2]);
      c.dispose();
    });

    test('rating replaces the previous score and can be removed', () async {
      final c = MovieReviewsController(movieId: 1, repository: repo);
      await c.load();

      await c.rate(4);
      await c.rate(1);
      expect(c.summary.myScore, 1);
      expect(c.summary.count, 3);
      expect(c.myReview?.score, 1, reason: 'own card shows the new score');

      await c.removeRating();
      expect(c.summary.myScore, isNull);
      expect(c.summary.count, 2);
      expect(c.isSavingRating, isFalse);
      c.dispose();
    });

    test('like updates the card without reloading', () async {
      final c = MovieReviewsController(movieId: 1, repository: repo);
      await c.load();
      final target = c.highlights.latest.first;
      repo.calls.clear();

      await c.toggleLike(target);

      expect(c.highlights.latest.first.likedByMe, isTrue);
      expect(c.highlights.latest.first.likeCount, target.likeCount + 1);
      expect(repo.calls, ['like']);
      c.dispose();
    });

    test('surfaces load errors', () async {
      repo.failWith = const ReviewException('Connection failed.');
      final c = MovieReviewsController(movieId: 1, repository: repo);
      await c.load();
      expect(c.error, 'Connection failed.');
      expect(c.isLoading, isFalse);
      c.dispose();
    });

    test('signed-out viewers cannot rate', () async {
      repo.userId = null;
      final c = MovieReviewsController(movieId: 1, repository: repo);
      await c.load();
      expect(c.isSignedIn, isFalse);
      expect(c.myReview, isNull);
      await expectLater(
        c.rate(3),
        throwsA(
          isA<ReviewException>().having(
            (e) => e.requiresSignIn,
            'requiresSignIn',
            true,
          ),
        ),
      );
      c.dispose();
    });
  });

  group('AllReviewsController', () {
    test(
      'sorts, paginates by 10 and steps back after the last delete',
      () async {
        final repo = FakeReviewsRepository();
        for (var i = 1; i <= 11; i++) {
          repo.reviews.add(review(i, userId: 'u$i'));
          if (i <= 3) repo.ratings[('u$i', 1)] = i;
        }
        final c = AllReviewsController(movieId: 1, repository: repo);

        await c.load();
        expect(c.page?.totalPages, 2);
        expect(c.reviews, hasLength(10));

        await c.changeSort(ReviewSort.lowest);
        expect(c.reviews.take(3).map((r) => r.score), [1, 2, 3]);
        expect(c.reviews.last.score, isNull, reason: 'unrated last');

        await c.changeSort(ReviewSort.recent);
        await c.goToPage(2);
        expect(c.reviews.single.id, 1);

        // Make the only review on page 2 mine, delete it: page 1 is shown.
        repo.reviews.removeWhere((r) => r.id == 1);
        repo.reviews.add(review(1, userId: me, createdAt: DateTime(2025)));
        await c.goToPage(2);
        await c.deleteReview(c.reviews.single);
        expect(c.page?.page, 1);
        expect(c.page?.total, 10);
        c.dispose();
      },
    );
  });

  group('MyRatingsController', () {
    late FakeReviewsRepository repo;
    late MyRatingsController c;

    setUp(() {
      repo = FakeReviewsRepository()
        ..ratings[(me, 10)] = 4
        ..ratings[(me, 20)] = 2
        ..reviews.add(review(1, movieId: 20, userId: me, likes: 5))
        ..reviews.add(review(2, movieId: 30, userId: me, likes: 1));
      c = MyRatingsController(
        repository: repo,
        lookup: (id) async => id == 30
            ? null // removed from TMDB
            : Movie(
                id: id,
                title: 'Movie $id',
                overview: '',
                posterPath: null,
                backdropPath: null,
                voteAverage: 0,
                releaseDate: '2020-01-01',
              ),
      );
    });

    tearDown(() => c.dispose());

    test('loads activity, stats and removed movies', () async {
      await c.load();
      expect(c.items.map((i) => i.movieId).toSet(), {10, 20, 30});
      expect(c.stats.ratedCount, 2);
      expect(c.stats.averageScore, 3);
      expect(c.stats.likesReceived, 6);
      expect(c.isMovieRemoved(30), isTrue);
      expect(c.isMovieRemoved(10), isFalse);
      expect(c.movies[10]?.title, 'Movie 10');
    });

    test('rating changes and removals update the list and stats', () async {
      await c.load();

      await c.rate(10, 5);
      expect(c.stats.averageScore, 3.5);

      await c.removeRating(10);
      expect(
        c.items.any((i) => i.movieId == 10),
        isFalse,
        reason: 'nothing left for this movie',
      );

      await c.removeRating(20);
      final item20 = c.items.firstWhere((i) => i.movieId == 20);
      expect(item20.score, isNull);
      expect(item20.review, isNotNull, reason: 'review survives');
      expect(c.stats.ratedCount, 0);
    });

    test('deleting a review keeps the rating', () async {
      await c.load();
      await c.deleteReview(c.items.firstWhere((i) => i.movieId == 20));
      final item = c.items.firstWhere((i) => i.movieId == 20);
      expect(item.review, isNull);
      expect(item.score, 2);
      expect(c.stats.likesReceived, 1);

      await c.deleteReview(c.items.firstWhere((i) => i.movieId == 30));
      expect(c.items.any((i) => i.movieId == 30), isFalse);
    });

    test('signed out shows nothing', () async {
      repo.userId = null;
      await c.load();
      expect(c.isSignedIn, isFalse);
      expect(c.items, isEmpty);
      expect(repo.calls, isEmpty);
    });
  });
}
