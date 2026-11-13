import 'models/recommended_movie.dart';
import 'models/tmdb_candidate.dart';

// Recommendation ranking rules (pure functions, unit tested).
// Same rules as the validated web version (Module 6).

const int seedCount = 3; // starting movies (most recent)
const int topGenresCount = 3; // favorite genres kept
const int weightOccurrence = 2;
const int weightGenreMatch = 1;
const int weightQuality = 1;
const int matchMin = 55;
const int matchMax = 99;

const String reasonGenres = 'In your favorite genres';
const String reasonRated = 'Based on movies you rated highly';
const String reasonTrending = 'Trending this week';

class SignalMovie {
  const SignalMovie({
    required this.movieId,
    required this.title,
    required this.addedAt,
    this.genreIds = const [],
  });

  final int movieId;

  /// Empty for rated movies (title unknown) → reason [reasonRated].
  final String title;
  final List<int> genreIds;
  final DateTime addedAt;
}

class Seed {
  const Seed(this.movieId, this.title);
  final int movieId;
  final String title;
}

class UserSignals {
  const UserSignals({
    required this.seeds,
    required this.topGenres,
    required this.excludeIds,
  });

  final List<Seed> seeds;
  final List<int> topGenres;
  final Set<int> excludeIds;
}

/// [alsoExclude]: movies never recommended without being signals
/// (rated movies, watched movies).
UserSignals buildSignals(
  List<SignalMovie> movies, {
  Iterable<int> alsoExclude = const [],
}) {
  final byRecent = [...movies]..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  final seeds = <Seed>[];
  for (final m in byRecent) {
    if (seeds.length >= seedCount) break;
    if (!seeds.any((s) => s.movieId == m.movieId)) {
      seeds.add(Seed(m.movieId, m.title));
    }
  }

  final genreCount = <int, int>{};
  for (final m in movies) {
    for (final g in m.genreIds) {
      genreCount[g] = (genreCount[g] ?? 0) + 1;
    }
  }
  final sortedGenres = genreCount.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });

  return UserSignals(
    seeds: seeds,
    topGenres: sortedGenres.take(topGenresCount).map((e) => e.key).toList(),
    excludeIds: {...movies.map((m) => m.movieId), ...alsoExclude},
  );
}

/// Converts a score to a compatibility percentage (55–99 %).
/// Max score = every seed recommends it + every favorite genre + rating 10/10.
int toMatchPercent(double score, UserSignals signals) {
  final seeds = signals.seeds.isEmpty ? 1 : signals.seeds.length;
  final maxScore =
      weightOccurrence * seeds +
      weightGenreMatch * signals.topGenres.length +
      weightQuality;
  final ratio = (score / maxScore).clamp(0.0, 1.0);
  return (matchMin + (matchMax - matchMin) * ratio).round();
}

class CandidateGroup {
  const CandidateGroup({required this.seedTitle, required this.movies});

  /// Seed at the origin of the group; '' = rated movie; null = genre search.
  final String? seedTitle;
  final List<TmdbCandidate> movies;
}

String _reasonFor(String? seedTitle) => seedTitle == null
    ? reasonGenres
    : seedTitle.isEmpty
    ? reasonRated
    : 'Because you added $seedTitle';

class _Entry {
  _Entry(this.movie, this.occurrences, this.reason);
  final TmdbCandidate movie;
  int occurrences;
  String reason;
  double score = 0;
}

/// Score = 2 × seeds recommending it + 1 × shared favorite genres + TMDB rating / 10.
/// Movies already known by the user are excluded.
List<RecommendedMovie> rankCandidates(
  List<CandidateGroup> groups,
  UserSignals signals,
  int limit,
) {
  final entries = <int, _Entry>{};
  for (final group in groups) {
    final fromSeed = group.seedTitle != null;
    for (final movie in group.movies) {
      if (signals.excludeIds.contains(movie.id)) continue;
      final entry = entries[movie.id];
      if (entry == null) {
        entries[movie.id] = _Entry(
          movie,
          fromSeed ? 1 : 0,
          _reasonFor(group.seedTitle),
        );
      } else if (fromSeed) {
        entry.occurrences += 1;
        if (entry.occurrences == 1) entry.reason = _reasonFor(group.seedTitle);
      }
    }
  }

  final scored =
      entries.values.map((e) {
        final genreMatches = e.movie.genreIds
            .where(signals.topGenres.contains)
            .length;
        e.score =
            weightOccurrence * e.occurrences +
            weightGenreMatch * genreMatches +
            weightQuality * (e.movie.voteAverage / 10);
        return e;
      }).toList()..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        return byScore != 0 ? byScore : a.movie.id.compareTo(b.movie.id);
      });

  return scored
      .take(limit)
      .map(
        (e) => RecommendedMovie(
          movie: e.movie,
          reason: e.reason,
          match: toMatchPercent(e.score, signals),
        ),
      )
      .toList();
}
