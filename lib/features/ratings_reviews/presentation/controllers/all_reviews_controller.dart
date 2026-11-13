import 'package:flutter/foundation.dart';

import '../../data/repositories/reviews_repository_impl.dart';
import '../../domain/models/rating_summary.dart';
import '../../domain/models/review.dart';
import '../../domain/models/review_sort.dart';
import '../../domain/repositories/reviews_repository.dart';
import '../../domain/review_rules.dart';

/// Full, sortable and paginated review list of one movie.
class AllReviewsController extends ChangeNotifier {
  AllReviewsController({required this.movieId, ReviewsRepository? repository})
    : _repository = repository ?? ReviewsRepositoryImpl(),
      summary = RatingSummary.empty(movieId);

  final int movieId;
  final ReviewsRepository _repository;

  RatingSummary summary;
  ReviewSort sort = ReviewSort.recent;
  ReviewPage? page;
  bool isAdmin = false;
  bool isLoading = false;
  String? error;
  bool _disposed = false;
  int _requestId = 0;

  ReviewsRepository get repository => _repository;
  bool get isSignedIn => _repository.currentUserId != null;
  List<Review> get reviews => page?.reviews ?? const [];

  Future<void> load({int pageNumber = 1}) async {
    final requestId = ++_requestId;
    isLoading = true;
    error = null;
    _notify();

    try {
      final results = await Future.wait<Object>([
        _repository.getRatingSummary(movieId),
        _repository.getReviews(
          movieId,
          sort: sort,
          page: pageNumber,
          pageSize: ReviewRules.pageSize,
        ),
        _repository.isAdmin(),
      ]);
      if (requestId != _requestId) return; // a newer request won
      summary = results[0] as RatingSummary;
      var loaded = results[1] as ReviewPage;
      // The last page may have emptied (e.g. after a delete): step back.
      if (loaded.reviews.isEmpty && pageNumber > 1) {
        loaded = await _repository.getReviews(
          movieId,
          sort: sort,
          page: pageNumber - 1,
          pageSize: ReviewRules.pageSize,
        );
      }
      page = loaded;
      isAdmin = results[2] as bool;
    } on ReviewException catch (e) {
      if (requestId == _requestId) error = e.message;
    } catch (_) {
      if (requestId == _requestId) error = 'Could not load reviews.';
    } finally {
      if (requestId == _requestId) {
        isLoading = false;
        _notify();
      }
    }
  }

  Future<void> changeSort(ReviewSort value) async {
    if (value == sort) return;
    sort = value;
    await load();
  }

  Future<void> goToPage(int pageNumber) => load(pageNumber: pageNumber);

  Future<void> reload() => load(pageNumber: page?.page ?? 1);

  Future<void> deleteReview(Review review) async {
    await _repository.deleteReview(review.id);
    await reload();
  }

  Future<void> toggleLike(Review review) async {
    final updated = await _repository.toggleLike(review);
    final current = page;
    if (current == null) return;
    page = ReviewPage(
      reviews: [
        for (final r in current.reviews) r.id == updated.id ? updated : r,
      ],
      page: current.page,
      total: current.total,
      pageSize: current.pageSize,
    );
    _notify();
  }

  Future<void> report(Review review, String reason) =>
      _repository.reportReview(review.id, reason);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
