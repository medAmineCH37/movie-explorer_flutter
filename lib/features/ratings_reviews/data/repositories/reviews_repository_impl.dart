import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/ai_review_summary.dart';
import '../../domain/models/rating_summary.dart';
import '../../domain/models/review.dart';
import '../../domain/models/review_activity.dart';
import '../../domain/models/review_sort.dart';
import '../../domain/repositories/reviews_repository.dart';
import '../../domain/review_rules.dart';
import '../services/reviews_service.dart';

/// Supabase-backed [ReviewsRepository]. Converts database and network
/// errors into [ReviewException]s with user-facing messages.
class ReviewsRepositoryImpl implements ReviewsRepository {
  ReviewsRepositoryImpl({ReviewsService? service})
    : _service = service ?? ReviewsService();

  final ReviewsService _service;

  static const _signInMessage = 'Sign in to continue.';
  static const _networkMessage =
      'Connection failed. Check your network and try again.';

  @override
  String? get currentUserId => _service.currentUserId;

  void _requireSignIn() => _userId;

  String get _userId {
    final id = _service.currentUserId;
    if (id == null) {
      throw const ReviewException(_signInMessage, requiresSignIn: true);
    }
    return id;
  }

  @override
  Future<bool> isAdmin() async {
    if (currentUserId == null) return false;
    try {
      return await _service.isAdmin();
    } catch (_) {
      // Admin actions are optional; never block the page on this check.
      return false;
    }
  }

  @override
  Future<RatingSummary> getRatingSummary(int movieId) => _guard(() async {
    return RatingSummary.fromJson(await _service.getRatingSummary(movieId));
  });

  @override
  Future<RatingSummary> rateMovie(int movieId, int score) => _guard(() async {
    if (score < ReviewRules.minScore || score > ReviewRules.maxScore) {
      throw const ReviewException('Ratings go from 1 to 5 stars.');
    }
    await _service.upsertRating(_userId, movieId, score);
    return getRatingSummary(movieId);
  });

  @override
  Future<RatingSummary> removeRating(int movieId) => _guard(() async {
    final deleted = await _service.deleteRating(_userId, movieId);
    if (deleted == 0) {
      throw const ReviewException("You haven't rated this movie.");
    }
    return getRatingSummary(movieId);
  });

  @override
  Future<ReviewPage> getReviews(
    int movieId, {
    ReviewSort sort = ReviewSort.recent,
    int page = 1,
    int pageSize = ReviewRules.pageSize,
  }) => _guard(() async {
    final rows = await _service.getReviews(
      movieId: movieId,
      sort: sort.value,
      page: page,
      pageSize: pageSize,
    );
    return ReviewPage(
      reviews: _toReviews(rows),
      page: page,
      pageSize: pageSize,
      total: rows.isEmpty ? 0 : (rows.first['total_count'] as num).toInt(),
    );
  });

  @override
  Future<Review?> getMyReview(int movieId) => _guard(() async {
    final userId = currentUserId;
    if (userId == null) return null;
    final rows = await _service.getReviews(movieId: movieId, authorId: userId);
    final reviews = _toReviews(rows);
    return reviews.isEmpty ? null : reviews.first;
  });

  @override
  Future<Review> createReview(
    int movieId, {
    required String content,
    required bool spoiler,
  }) => _guard(() async {
    final userId = _userId;
    final text = _validContent(content);
    try {
      await _service.insertReview(userId, movieId, text, spoiler);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const ReviewException(
          'You already reviewed this movie. Edit your review instead.',
        );
      }
      rethrow;
    }
    return _requireMyReview(movieId);
  });

  @override
  Future<Review> updateReview(
    int reviewId, {
    required String content,
    required bool spoiler,
  }) => _guard(() async {
    _requireSignIn();
    final text = _validContent(content);
    final movieId = await _service.updateReview(reviewId, text, spoiler);
    if (movieId == null) {
      throw const ReviewException('Review not found.');
    }
    return _requireMyReview(movieId);
  });

  @override
  Future<void> deleteReview(int reviewId) => _guard(() async {
    _requireSignIn();
    final deleted = await _service.deleteReview(reviewId);
    if (deleted == 0) {
      throw const ReviewException(
        'This review no longer exists or you cannot delete it.',
      );
    }
  });

  @override
  Future<Review> toggleLike(Review review) => _guard(() async {
    final userId = _userId;
    if (review.isMine) {
      throw const ReviewException('You cannot like your own review.');
    }
    if (review.likedByMe) {
      await _service.unlike(review.id, userId);
      return review.copyWith(likedByMe: false, likeCount: review.likeCount - 1);
    }
    try {
      await _service.like(review.id, userId);
    } on PostgrestException catch (e) {
      // Already liked from another device: the end state is the same.
      if (e.code != '23505') rethrow;
      return review.copyWith(likedByMe: true);
    }
    return review.copyWith(likedByMe: true, likeCount: review.likeCount + 1);
  });

  @override
  Future<void> reportReview(int reviewId, String reason) => _guard(() async {
    final userId = _userId;
    final error = ReviewRules.validateReportReason(reason);
    if (error != null) throw ReviewException(error);
    try {
      await _service.report(reviewId, userId, reason.trim());
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const ReviewException('You already reported this review.');
      }
      rethrow;
    }
  });

  @override
  Future<List<ReviewActivity>> getMyActivity() => _guard(() async {
    final userId = _userId;
    final ratingRows = await _service.getMyRatings(userId);
    final reviews = <Review>[];
    const pageSize = 100;
    for (var page = 1; ; page++) {
      final rows = await _service.getReviews(
        authorId: userId,
        page: page,
        pageSize: pageSize,
      );
      reviews.addAll(_toReviews(rows));
      if (rows.length < pageSize) break;
    }

    return ReviewActivity.merge(
      ratings: {
        for (final row in ratingRows)
          (row['tmdb_movie_id'] as num).toInt(): (
            (row['score'] as num).toInt(),
            DateTime.parse(row['updated_at'] as String).toLocal(),
          ),
      },
      reviews: reviews,
    );
  });

  @override
  Future<String> draftReview({
    required int movieId,
    required String movieTitle,
    String? movieYear,
    required String keywords,
  }) => _guard(() async {
    _requireSignIn();
    final error = ReviewRules.validateAiKeywords(keywords);
    if (error != null) throw ReviewException(error);
    final data = await _service.invokeAi({
      'action': 'draft',
      'movieId': movieId,
      'movieTitle': movieTitle,
      'movieYear': movieYear,
      'keywords': keywords.trim(),
    });
    final draft = (data['draft'] as String? ?? '').trim();
    if (draft.isEmpty) {
      throw const ReviewException('The assistant returned an empty draft.');
    }
    return draft;
  });

  @override
  Future<AiReviewSummary> getAiSummary(int movieId) => _guard(() async {
    final data = await _service.invokeAi({
      'action': 'summary',
      'movieId': movieId,
    });
    return AiReviewSummary.fromJson(data);
  });

  // -------------------------------------------------------------------------

  List<Review> _toReviews(List<Map<String, dynamic>> rows) => rows
      .map((row) => Review.fromJson(row, currentUserId: currentUserId))
      .toList();

  Future<Review> _requireMyReview(int movieId) async {
    final review = await getMyReview(movieId);
    if (review == null) throw const ReviewException('Review not found.');
    return review;
  }

  String _validContent(String content) {
    final error = ReviewRules.validateContent(content);
    if (error != null) throw ReviewException(error);
    return content.trim();
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ReviewException {
      rethrow;
    } on PostgrestException catch (e) {
      throw ReviewException(_postgrestMessage(e));
    } on FunctionException catch (e) {
      throw ReviewException(_functionMessage(e));
    } on AuthException {
      throw const ReviewException(_signInMessage, requiresSignIn: true);
    } on SocketException {
      throw const ReviewException(_networkMessage);
    } on http.ClientException {
      throw const ReviewException(_networkMessage);
    } on TimeoutException {
      throw const ReviewException(_networkMessage);
    }
  }

  static String _postgrestMessage(PostgrestException e) {
    switch (e.code) {
      case '23505':
        return 'This action was already done.';
      case '23514':
        return 'Some values are not valid. Check the text length and try again.';
      case '42501':
        return 'You are not allowed to do this.';
      case 'PGRST301':
      case 'PGRST303':
        return 'Your session expired. Sign in again.';
    }
    if (e.message.contains('own_review_like')) {
      return 'You cannot like your own review.';
    }
    if (e.message.contains('own_review_report')) {
      return 'You cannot report your own review.';
    }
    return 'Something went wrong. Please try again.';
  }

  static String _functionMessage(FunctionException e) {
    final details = e.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    if (e.status == 401) return _signInMessage;
    return 'The AI assistant is unavailable right now. Try again in a moment.';
  }
}
