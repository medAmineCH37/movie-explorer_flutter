import 'package:movie_explorer/features/ratings_reviews/domain/models/rating_summary.dart';
import 'package:movie_explorer/features/ratings_reviews/domain/models/review.dart';
import 'package:movie_explorer/features/ratings_reviews/domain/models/review_activity.dart';
import 'package:movie_explorer/features/ratings_reviews/domain/models/review_sort.dart';
import 'package:movie_explorer/features/ratings_reviews/domain/repositories/reviews_repository.dart';

const me = 'user-me';

Review review(
  int id, {
  int movieId = 1,
  String userId = 'someone',
  String content = 'A solid movie with great acting.',
  bool spoiler = false,
  int? score,
  int likes = 0,
  bool likedByMe = false,
  bool edited = false,
  String author = 'Sam',
  DateTime? createdAt,
}) {
  final date = createdAt ?? DateTime(2026, 1, id);
  return Review(
    id: id,
    movieId: movieId,
    userId: userId,
    content: content,
    spoiler: spoiler,
    score: score,
    likeCount: likes,
    likedByMe: likedByMe,
    edited: edited,
    authorName: author,
    authorAvatarUrl: null,
    createdAt: date,
    updatedAt: date,
    isMine: userId == me,
  );
}

/// In-memory [ReviewsRepository] applying the same rules as the database.
class FakeReviewsRepository implements ReviewsRepository {
  FakeReviewsRepository({this.userId = me});

  String? userId;
  bool admin = false;
  final Map<(String, int), int> ratings = {};
  final List<Review> reviews = [];
  final Set<(int, String)> reports = {};
  final List<String> calls = [];
  ReviewException? failWith;

  @override
  String? get currentUserId => userId;

  void _check(String call) {
    calls.add(call);
    if (failWith != null) throw failWith!;
  }

  String get _user {
    if (userId == null) {
      throw const ReviewException('Sign in to continue.', requiresSignIn: true);
    }
    return userId!;
  }

  Review _view(Review r) => Review(
    id: r.id,
    movieId: r.movieId,
    userId: r.userId,
    content: r.content,
    spoiler: r.spoiler,
    score: ratings[(r.userId, r.movieId)],
    likeCount: r.likeCount,
    likedByMe: r.likedByMe,
    edited: r.edited,
    authorName: r.authorName,
    authorAvatarUrl: null,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
    isMine: r.userId == userId,
  );

  @override
  Future<bool> isAdmin() async => admin;

  @override
  Future<RatingSummary> getRatingSummary(int movieId) async {
    _check('summary');
    final scores = [
      for (final e in ratings.entries)
        if (e.key.$2 == movieId) e.value,
    ];
    return RatingSummary(
      movieId: movieId,
      average: scores.isEmpty
          ? 0
          : (scores.reduce((a, b) => a + b) / scores.length * 10).round() / 10,
      count: scores.length,
      distribution: [
        for (var s = 1; s <= 5; s++) scores.where((v) => v == s).length,
      ],
      myScore: userId == null ? null : ratings[(userId!, movieId)],
      reviewCount: reviews.where((r) => r.movieId == movieId).length,
    );
  }

  @override
  Future<RatingSummary> rateMovie(int movieId, int score) async {
    _check('rate');
    ratings[(_user, movieId)] = score;
    return getRatingSummary(movieId);
  }

  @override
  Future<RatingSummary> removeRating(int movieId) async {
    _check('removeRating');
    if (ratings.remove((_user, movieId)) == null) {
      throw const ReviewException("You haven't rated this movie.");
    }
    return getRatingSummary(movieId);
  }

  @override
  Future<ReviewPage> getReviews(
    int movieId, {
    ReviewSort sort = ReviewSort.recent,
    int page = 1,
    int pageSize = 10,
  }) async {
    _check('reviews:${sort.value}:$page');
    final list = reviews.where((r) => r.movieId == movieId).map(_view).toList();
    int byDate(Review a, Review b) => b.createdAt.compareTo(a.createdAt);
    list.sort(switch (sort) {
      ReviewSort.recent => byDate,
      ReviewSort.likes => (a, b) {
        final c = b.likeCount.compareTo(a.likeCount);
        return c != 0 ? c : byDate(a, b);
      },
      ReviewSort.highest => (a, b) {
        final c = (b.score ?? 0).compareTo(a.score ?? 0);
        return c != 0 ? c : byDate(a, b);
      },
      ReviewSort.lowest => (a, b) {
        final c = (a.score ?? 6).compareTo(b.score ?? 6);
        return c != 0 ? c : byDate(a, b);
      },
    });
    return ReviewPage(
      reviews: list.skip((page - 1) * pageSize).take(pageSize).toList(),
      page: page,
      total: list.length,
      pageSize: pageSize,
    );
  }

  @override
  Future<Review?> getMyReview(int movieId) async {
    if (userId == null) return null;
    final mine = reviews.where(
      (r) => r.movieId == movieId && r.userId == userId,
    );
    return mine.isEmpty ? null : _view(mine.first);
  }

  @override
  Future<Review> createReview(
    int movieId, {
    required String content,
    required bool spoiler,
  }) async {
    _check('create');
    final user = _user;
    if (reviews.any((r) => r.movieId == movieId && r.userId == user)) {
      throw const ReviewException(
        'You already reviewed this movie. Edit your review instead.',
      );
    }
    final created = review(
      100 + reviews.length,
      movieId: movieId,
      userId: user,
      content: content.trim(),
      spoiler: spoiler,
      author: 'Me',
      createdAt: DateTime.now(),
    );
    reviews.add(created);
    return _view(created);
  }

  @override
  Future<Review> updateReview(
    int reviewId, {
    required String content,
    required bool spoiler,
  }) async {
    _check('update');
    final index = reviews.indexWhere(
      (r) => r.id == reviewId && r.userId == _user,
    );
    if (index < 0) throw const ReviewException('Review not found.');
    reviews[index] = reviews[index].copyWith(
      content: content.trim(),
      spoiler: spoiler,
      edited: true,
    );
    return _view(reviews[index]);
  }

  @override
  Future<void> deleteReview(int reviewId) async {
    _check('delete');
    final user = _user;
    final before = reviews.length;
    reviews.removeWhere((r) => r.id == reviewId && (r.userId == user || admin));
    if (reviews.length == before) {
      throw const ReviewException('This review no longer exists.');
    }
  }

  @override
  Future<Review> toggleLike(Review target) async {
    _check('like');
    _user;
    if (target.isMine) {
      throw const ReviewException('You cannot like your own review.');
    }
    final index = reviews.indexWhere((r) => r.id == target.id);
    final current = reviews[index];
    final liked = !current.likedByMe;
    reviews[index] = current.copyWith(
      likedByMe: liked,
      likeCount: current.likeCount + (liked ? 1 : -1),
    );
    return _view(reviews[index]);
  }

  @override
  Future<void> reportReview(int reviewId, String reason) async {
    _check('report');
    if (!reports.add((reviewId, _user))) {
      throw const ReviewException('You already reported this review.');
    }
  }

  @override
  Future<List<ReviewActivity>> getMyActivity() async {
    _check('activity');
    final user = _user;
    return ReviewActivity.merge(
      ratings: {
        for (final e in ratings.entries)
          if (e.key.$1 == user)
            e.key.$2: (e.value, DateTime(2026, 2, e.key.$2)),
      },
      reviews: reviews.where((r) => r.userId == user).map(_view).toList(),
    );
  }
}
