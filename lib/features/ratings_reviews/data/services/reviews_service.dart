import 'package:supabase_flutter/supabase_flutter.dart';

/// Raw Supabase access for ratings, reviews, likes and reports.
///
/// Authorisation and validation are enforced by the database (RLS, CHECK
/// constraints and triggers); see
/// `supabase/migrations/20261111_ratings_reviews.sql`.
class ReviewsService {
  ReviewsService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<bool> isAdmin() async {
    final result = await _client.rpc<dynamic>('is_admin');
    return result == true;
  }

  Future<Map<String, dynamic>> getRatingSummary(int movieId) async {
    final result = await _client.rpc<dynamic>(
      'get_movie_rating_summary',
      params: {'p_movie_id': movieId},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<void> upsertRating(String userId, int movieId, int score) async {
    await _client.from('ratings').upsert({
      'user_id': userId,
      'tmdb_movie_id': movieId,
      'score': score,
    }, onConflict: 'user_id,tmdb_movie_id');
  }

  /// Returns the number of deleted rows (0 or 1).
  Future<int> deleteRating(String userId, int movieId) async {
    final rows = await _client
        .from('ratings')
        .delete()
        .eq('user_id', userId)
        .eq('tmdb_movie_id', movieId)
        .select('id');
    return rows.length;
  }

  Future<List<Map<String, dynamic>>> getMyRatings(String userId) async {
    final rows = await _client
        .from('ratings')
        .select('tmdb_movie_id, score, updated_at')
        .eq('user_id', userId);
    return rows;
  }

  Future<List<Map<String, dynamic>>> getReviews({
    int? movieId,
    String? authorId,
    String sort = 'recent',
    int page = 1,
    int pageSize = 10,
  }) async {
    final result = await _client.rpc<dynamic>(
      'get_reviews',
      params: {
        'p_movie_id': movieId,
        'p_author': authorId,
        'p_sort': sort,
        'p_page': page,
        'p_page_size': pageSize,
      },
    );
    return (result as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<void> insertReview(
    String userId,
    int movieId,
    String content,
    bool spoiler,
  ) async {
    await _client.from('reviews').insert({
      'user_id': userId,
      'tmdb_movie_id': movieId,
      'content': content,
      'spoiler': spoiler,
    });
  }

  /// Returns the updated row's movie id, or `null` if nothing was updated
  /// (unknown review or not the author).
  Future<int?> updateReview(int reviewId, String content, bool spoiler) async {
    final rows = await _client
        .from('reviews')
        .update({'content': content, 'spoiler': spoiler})
        .eq('id', reviewId)
        .select('tmdb_movie_id');
    if (rows.isEmpty) return null;
    return (rows.first['tmdb_movie_id'] as num).toInt();
  }

  /// Returns the number of deleted rows (0 or 1).
  Future<int> deleteReview(int reviewId) async {
    final rows = await _client
        .from('reviews')
        .delete()
        .eq('id', reviewId)
        .select('id');
    return rows.length;
  }

  Future<void> like(int reviewId, String userId) async {
    await _client.from('review_likes').insert({
      'review_id': reviewId,
      'user_id': userId,
    });
  }

  Future<void> unlike(int reviewId, String userId) async {
    await _client
        .from('review_likes')
        .delete()
        .eq('review_id', reviewId)
        .eq('user_id', userId);
  }

  Future<void> report(int reviewId, String userId, String reason) async {
    await _client.from('review_reports').insert({
      'review_id': reviewId,
      'reporter_user_id': userId,
      'reason': reason,
    });
  }
}
