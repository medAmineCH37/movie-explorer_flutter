import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/custom_list.dart';
import '../domain/models/recommended_movie.dart';
import '../domain/models/tmdb_candidate.dart';
import '../domain/ranking.dart';
import 'custom_list_repository.dart';
import 'reco_tmdb_service.dart';

/// Ratings signals (Module 3). Liked movies become signals, every rated movie
/// is excluded from recommendations.
class RatingSignals {
  const RatingSignals({this.liked = const [], this.ratedIds = const []});
  final List<SignalMovie> liked;
  final List<int> ratedIds;
}

abstract class RatingSignalSource {
  Future<RatingSignals> load(String userId);
}

/// Source without ratings (tests, or when the ratings module is unavailable).
class PendingRatingSignalSource implements RatingSignalSource {
  const PendingRatingSignalSource();

  @override
  Future<RatingSignals> load(String userId) async => const RatingSignals();
}

/// Reads the Ratings & Reviews module's 1–5 `ratings.score` values.
/// Movies rated [likedMin] or more are signals; every rated movie is excluded.
class ReviewsRatingSignalSource implements RatingSignalSource {
  ReviewsRatingSignalSource({required this.likedMin, SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final int likedMin;
  final SupabaseClient _client;

  @override
  Future<RatingSignals> load(String userId) async {
    final rows = await _client
        .from('ratings')
        .select('tmdb_movie_id, score, updated_at')
        .eq('user_id', userId)
        .order('updated_at', ascending: false)
        .limit(200);
    return RatingSignals(
      liked: rows
          .where((r) => (r['score'] as num) >= likedMin)
          .map(
            (r) => SignalMovie(
              movieId: (r['tmdb_movie_id'] as num).toInt(),
              title: '',
              addedAt:
                  DateTime.tryParse(r['updated_at'] as String) ??
                  DateTime(2000),
            ),
          )
          .toList(),
      ratedIds: rows.map((r) => (r['tmdb_movie_id'] as num).toInt()).toList(),
    );
  }
}

class RecommendationService {
  RecommendationService({
    RecoTmdbService? tmdb,
    CustomListRepository? lists,
    SupabaseClient? client,
    RatingSignalSource? ratings,
  }) : tmdb = tmdb ?? RecoTmdbService(),
       _lists = lists ?? CustomListRepository(client: client),
       _client = client ?? Supabase.instance.client,
       ratings =
           ratings ??
           ReviewsRatingSignalSource(likedMin: likedRatingMin, client: client);

  final RecoTmdbService tmdb;
  final CustomListRepository _lists;
  final SupabaseClient _client;
  final RatingSignalSource ratings;

  /// Movies rated 4 or 5 out of 5 are used as recommendation signals.
  static const int likedRatingMin = 4;

  static const int _favoriteLimit = 10;

  /// Personal recommendations; trending when the user has no signal.
  Future<RecommendationsResult> forCurrentUser({int limit = 20}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return trendingResult(limit: limit);

    final results = await Future.wait([
      _lists.mySignalMovies(),
      _optional(() => _favoriteMovies(userId), const <SignalMovie>[]),
      _optional(() => ratings.load(userId), const RatingSignals()),
      _optional(() => _watchedIds(userId), const <int>[]),
    ]);
    final rated = results[2] as RatingSignals;
    final movies = [
      ...results[0] as List<SignalMovie>,
      ...results[1] as List<SignalMovie>,
      ...rated.liked,
    ];
    final signals = buildSignals(
      movies,
      alsoExclude: [...rated.ratedIds, ...results[3] as List<int>],
    );
    return _rank(signals, RecommendationSource.personal, limit);
  }

  /// Recommendations based only on the movies of [list].
  Future<RecommendationsResult> forList(CustomList list, {int limit = 20}) {
    final signals = buildSignals([
      for (final m in list.movies)
        SignalMovie(
          movieId: m.movieId,
          title: m.title,
          genreIds: m.genreIds,
          addedAt: m.addedAt ?? DateTime(2000),
        ),
    ]);
    return _rank(signals, RecommendationSource.list, limit);
  }

  Future<RecommendationsResult> trendingResult({int limit = 20}) async {
    final movies = await tmdb.trending();
    return RecommendationsResult(
      source: RecommendationSource.trending,
      results: movies
          .take(limit)
          .map((m) => RecommendedMovie(movie: m, reason: reasonTrending))
          .toList(),
    );
  }

  Future<RecommendationsResult> _rank(
    UserSignals signals,
    RecommendationSource source,
    int limit,
  ) async {
    if (signals.seeds.isEmpty) return trendingResult(limit: limit);

    final groups = await Future.wait([
      for (final seed in signals.seeds)
        _optional(
          () async => CandidateGroup(
            seedTitle: seed.title,
            movies: await tmdb.recommendations(seed.movieId),
          ),
          CandidateGroup(seedTitle: seed.title, movies: const []),
        ),
      if (signals.topGenres.isNotEmpty)
        _optional(
          () async => CandidateGroup(
            seedTitle: null,
            movies: await tmdb.discoverByGenres(signals.topGenres),
          ),
          const CandidateGroup(seedTitle: null, movies: []),
        ),
    ]);

    final ranked = rankCandidates(groups, signals, limit);
    if (ranked.isEmpty) return trendingResult(limit: limit);
    return RecommendationsResult(
      source: source,
      results: ranked,
      topGenres: signals.topGenres,
    );
  }

  /// Favorites (Module 4 table, read-only): TMDB details give title and genres.
  Future<List<SignalMovie>> _favoriteMovies(String userId) async {
    final rows = await _client
        .from('favorites')
        .select('tmdb_movie_id, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(_favoriteLimit);
    final movies = await Future.wait(
      rows.map(
        (r) => _optional<TmdbCandidate?>(
          () => tmdb.details((r['tmdb_movie_id'] as num).toInt()),
          null,
        ),
      ),
    );
    return [
      for (var i = 0; i < rows.length; i++)
        if (movies[i] != null)
          SignalMovie(
            movieId: movies[i]!.id,
            title: movies[i]!.title,
            genreIds: movies[i]!.genreIds,
            addedAt:
                DateTime.tryParse(rows[i]['created_at'] as String) ??
                DateTime(2000),
          ),
    ];
  }

  /// Watched movies (Module 4) are never recommended.
  Future<List<int>> _watchedIds(String userId) async {
    final rows = await _client
        .from('watched_movies')
        .select('tmdb_movie_id')
        .eq('user_id', userId);
    return rows.map((r) => (r['tmdb_movie_id'] as num).toInt()).toList();
  }

  /// Optional sources improve recommendations but never block them.
  static Future<T> _optional<T>(Future<T> Function() load, T fallback) async {
    try {
      return await load();
    } catch (_) {
      return fallback;
    }
  }
}
