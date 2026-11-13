import 'package:flutter_test/flutter_test.dart';
import 'package:movie_explorer/features/ratings_reviews/domain/models/ai_review_summary.dart';
import 'package:movie_explorer/features/ratings_reviews/domain/models/rating_summary.dart';
import 'package:movie_explorer/features/ratings_reviews/domain/models/review.dart';
import 'package:movie_explorer/features/ratings_reviews/domain/models/review_activity.dart';
import 'package:movie_explorer/features/ratings_reviews/domain/models/review_sort.dart';
import 'package:movie_explorer/features/ratings_reviews/domain/review_rules.dart';
import 'package:movie_explorer/features/ratings_reviews/presentation/relative_time.dart';
import 'package:movie_explorer/features/ratings_reviews/presentation/widgets/star_rating.dart';

import 'fake_reviews_repository.dart';

void main() {
  group('ReviewRules', () {
    test('score labels', () {
      expect(ReviewRules.scoreLabel(1), 'Mauvais');
      expect(ReviewRules.scoreLabel(2), 'Moyen');
      expect(ReviewRules.scoreLabel(3), 'Bien');
      expect(ReviewRules.scoreLabel(4), 'Très bien');
      expect(ReviewRules.scoreLabel(5), "Chef-d'œuvre");
      expect(ReviewRules.scoreLabel(null), isNull);
    });

    test('content is 3–1000 characters after trimming', () {
      expect(ReviewRules.validateContent('  ab  '), isNotNull);
      expect(ReviewRules.validateContent(' abc '), isNull);
      expect(ReviewRules.validateContent('x' * 1000), isNull);
      expect(ReviewRules.validateContent('x' * 1001), isNotNull);
    });

    test('report reason is 3–300 characters after trimming', () {
      expect(ReviewRules.validateReportReason(' no '), isNotNull);
      expect(ReviewRules.validateReportReason('spam'), isNull);
      expect(ReviewRules.validateReportReason('r' * 301), isNotNull);
    });

    test('AI keywords need at least 2 characters', () {
      expect(ReviewRules.validateAiKeywords(' a '), isNotNull);
      expect(ReviewRules.validateAiKeywords('ok'), isNull);
    });
  });

  group('Review.fromJson', () {
    test('maps get_reviews rows and ownership', () {
      final json = {
        'id': 7,
        'tmdb_movie_id': 42,
        'user_id': me,
        'content': 'Nice',
        'spoiler': true,
        'score': null,
        'like_count': 3,
        'liked_by_me': false,
        'edited': true,
        'author_name': 'élodie',
        'author_avatar_url': 'not-a-url',
        'created_at': '2026-01-01T10:00:00+00:00',
        'updated_at': '2026-01-02T10:00:00+00:00',
        'total_count': 9,
      };
      final r = Review.fromJson(json, currentUserId: me);
      expect(r.id, 7);
      expect(r.movieId, 42);
      expect(r.isMine, isTrue);
      expect(r.score, isNull);
      expect(r.likeCount, 3);
      expect(r.edited, isTrue);
      expect(r.authorInitial, 'É');
      expect(r.hasAvatar, isFalse);
      expect(Review.fromJson(json, currentUserId: 'other').isMine, isFalse);
      expect(Review.fromJson(json).isMine, isFalse);
    });
  });

  group('RatingSummary', () {
    test('parses and scales bars to the largest bucket', () {
      final s = RatingSummary.fromJson({
        'tmdb_movie_id': 1,
        'average': 3.7,
        'count': 6,
        'distribution': [0, 1, 1, 0, 4],
        'my_score': 5,
        'review_count': 2,
      });
      expect(s.average, 3.7);
      expect(s.votesFor(5), 4);
      expect(s.barFraction(5), 1);
      expect(s.barFraction(2), 0.25);
      expect(s.barFraction(1), 0);
      expect(s.myScore, 5);
      expect(const RatingSummary.empty(1).barFraction(3), 0);
    });
  });

  group('StarRatingDisplay.roundToHalf', () {
    test('rounds to the nearest half star', () {
      expect(StarRatingDisplay.roundToHalf(3.2), 3.0);
      expect(StarRatingDisplay.roundToHalf(3.3), 3.5);
      expect(StarRatingDisplay.roundToHalf(3.75), 4.0);
      expect(StarRatingDisplay.roundToHalf(0), 0);
    });
  });

  group('ReviewHighlights.compose', () {
    test('pins mine, highlights most liked, then three latest', () {
      final mine = review(1, userId: me);
      final top = review(2, likes: 5);
      final recent = [review(9), top, review(8), mine, review(7), review(6)];
      final h = ReviewHighlights.compose(
        mine: mine,
        mostLiked: top,
        recent: recent,
      );
      expect(h.mine?.id, 1);
      expect(h.top?.id, 2);
      expect(h.latest.map((r) => r.id), [9, 8, 7]);
    });

    test('no highlight without likes or when it is my review', () {
      final unliked = review(2);
      expect(
        ReviewHighlights.compose(
          mine: null,
          mostLiked: unliked,
          recent: [unliked],
        ).top,
        isNull,
      );
      final mine = review(1, userId: me, likes: 4);
      final h = ReviewHighlights.compose(
        mine: mine,
        mostLiked: mine,
        recent: [mine, review(3)],
      );
      expect(h.top, isNull);
      expect(h.latest.map((r) => r.id), [3]);
      expect(
        ReviewHighlights.compose(
          mine: null,
          mostLiked: null,
          recent: [],
        ).isEmpty,
        isTrue,
      );
    });
  });

  group('ReviewPage', () {
    test('counts pages of 10', () {
      ReviewPage page(int total, int n) =>
          ReviewPage(reviews: const [], page: n, total: total, pageSize: 10);
      expect(page(0, 1).totalPages, 1);
      expect(page(10, 1).totalPages, 1);
      expect(page(11, 1).totalPages, 2);
      expect(page(11, 1).hasNext, isTrue);
      expect(page(11, 2).hasNext, isFalse);
      expect(page(11, 2).hasPrevious, isTrue);
    });
  });

  group('ReviewActivity', () {
    test('merges ratings and reviews, newest change first', () {
      final items = ReviewActivity.merge(
        ratings: {1: (4, DateTime(2026, 3)), 2: (2, DateTime(2026, 1))},
        reviews: [
          review(
            10,
            movieId: 2,
            userId: me,
            likes: 3,
            createdAt: DateTime(2026, 5),
          ),
          review(
            11,
            movieId: 3,
            userId: me,
            likes: 1,
            createdAt: DateTime(2026, 2),
          ),
        ],
      );
      expect(items.map((i) => i.movieId), [2, 1, 3]);
      expect(items.first.score, 2);
      expect(items.first.review?.id, 10);
      expect(items.last.score, isNull);

      final stats = ReviewStats.from(items);
      expect(stats.ratedCount, 2);
      expect(stats.averageScore, 3);
      expect(stats.likesReceived, 4);
      expect(ReviewStats.from(const []).averageScore, isNull);
    });
  });

  group('AiReviewSummary.fromJson', () {
    test('drops blank points', () {
      final s = AiReviewSummary.fromJson({
        'summary': ' Good. ',
        'strengths': ['Acting', ' ', 3],
        'weaknesses': null,
        'review_count': 4,
        'generated_at': '2026-11-11T10:00:00Z',
        'cached': true,
      });
      expect(s.summary, 'Good.');
      expect(s.strengths, ['Acting']);
      expect(s.weaknesses, isEmpty);
      expect(s.cached, isTrue);
    });
  });

  test('relativeTime', () {
    final now = DateTime(2026, 11, 11, 12);
    expect(
      relativeTime(now.subtract(const Duration(seconds: 5)), now: now),
      'just now',
    );
    expect(
      relativeTime(now.subtract(const Duration(minutes: 1)), now: now),
      '1 minute ago',
    );
    expect(
      relativeTime(now.subtract(const Duration(hours: 3)), now: now),
      '3 hours ago',
    );
    expect(
      relativeTime(now.subtract(const Duration(days: 1)), now: now),
      'yesterday',
    );
    expect(
      relativeTime(now.subtract(const Duration(days: 15)), now: now),
      '2 weeks ago',
    );
    expect(
      relativeTime(now.subtract(const Duration(days: 400)), now: now),
      '1 year ago',
    );
  });
}
