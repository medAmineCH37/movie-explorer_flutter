import 'package:flutter_test/flutter_test.dart';

import 'package:movie_explorer/features/recommendations_custom_lists/domain/models/tmdb_candidate.dart';
import 'package:movie_explorer/features/recommendations_custom_lists/domain/ranking.dart';

TmdbCandidate movie(int id, {List<int> genres = const [], double vote = 0}) =>
    TmdbCandidate(id: id, title: 'M$id', genreIds: genres, voteAverage: vote);

SignalMovie signal(int id, int day, {List<int> genres = const []}) =>
    SignalMovie(
      movieId: id,
      title: 'S$id',
      genreIds: genres,
      addedAt: DateTime(2026, 1, day),
    );

void main() {
  group('buildSignals', () {
    test('keeps the 3 most recent movies as seeds, without duplicates', () {
      final s = buildSignals([
        signal(1, 1),
        signal(2, 5),
        signal(2, 6),
        signal(3, 3),
        signal(4, 4),
      ]);
      expect(s.seeds.map((e) => e.movieId).toList(), [2, 4, 3]);
    });

    test('keeps the 3 most frequent genres (ties: lowest id first)', () {
      final s = buildSignals([
        signal(1, 1, genres: [28, 12, 35]),
        signal(2, 2, genres: [28, 12]),
        signal(3, 3, genres: [18, 35]),
        signal(4, 4, genres: [99]),
      ]);
      expect(s.topGenres, [12, 28, 35]);
    });

    test('excludes signal movies and extra ids (rated, watched)', () {
      final s = buildSignals([signal(1, 1)], alsoExclude: [9]);
      expect(s.excludeIds, {1, 9});
    });

    test('no movie means no seed', () {
      expect(buildSignals([]).seeds.isEmpty, true);
    });
  });

  group('rankCandidates', () {
    final signals = buildSignals([
      signal(1, 3, genres: [28]),
      signal(2, 2, genres: [28]),
      signal(3, 1, genres: [12]),
    ]);

    test('score = 2 × seeds + 1 × common genres + rating / 10', () {
      final results = rankCandidates(
        [
          CandidateGroup(
            seedTitle: 'S1',
            movies: [
              movie(10, genres: [28], vote: 5),
            ],
          ),
          CandidateGroup(
            seedTitle: 'S2',
            movies: [
              movie(10, genres: [28], vote: 5),
            ],
          ),
          CandidateGroup(
            seedTitle: null,
            movies: [
              movie(11, genres: [28, 12], vote: 9),
            ],
          ),
        ],
        signals,
        10,
      );
      // 10: 2×2 + 1 + 0.5 = 5.5 ; 11: 0 + 2 + 0.9 = 2.9
      expect(results.map((r) => r.movie.id).toList(), [10, 11]);
    });

    test('excludes known movies', () {
      final results = rankCandidates(
        [
          CandidateGroup(seedTitle: 'S1', movies: [movie(1), movie(20)]),
        ],
        signals,
        10,
      );
      expect(results.map((r) => r.movie.id).toList(), [20]);
    });

    test('compatibility stays between 55 and 99', () {
      final results = rankCandidates(
        [
          CandidateGroup(
            seedTitle: 'S1',
            movies: [
              movie(30, genres: [28, 12], vote: 10),
            ],
          ),
          CandidateGroup(
            seedTitle: 'S2',
            movies: [
              movie(30, genres: [28, 12], vote: 10),
            ],
          ),
          CandidateGroup(
            seedTitle: 'S3',
            movies: [
              movie(30, genres: [28, 12], vote: 10),
            ],
          ),
          CandidateGroup(seedTitle: null, movies: [movie(31)]),
        ],
        signals,
        10,
      );
      // 30: 3 seeds × 2 + 2 genres + 10/10 = max score → 99 ; 31: score 0 → 55
      expect(results.first.match, 99);
      expect(results.last.match, 55);
    });

    test('reason names the first seed, then rated, then genres', () {
      final results = rankCandidates(
        [
          CandidateGroup(seedTitle: null, movies: [movie(40)]),
          CandidateGroup(seedTitle: 'Inception', movies: [movie(40)]),
          CandidateGroup(seedTitle: '', movies: [movie(41)]),
          CandidateGroup(seedTitle: null, movies: [movie(42)]),
        ],
        signals,
        10,
      );
      final reasons = {for (final r in results) r.movie.id: r.reason};
      expect(reasons[40], 'Because you added Inception');
      expect(reasons[41], reasonRated);
      expect(reasons[42], reasonGenres);
    });

    test('respects the limit', () {
      final results = rankCandidates(
        [
          CandidateGroup(
            seedTitle: 'S1',
            movies: [for (var i = 100; i < 130; i++) movie(i)],
          ),
        ],
        signals,
        5,
      );
      expect(results.length, 5);
    });
  });

  group('toMatchPercent', () {
    final signals = buildSignals([
      signal(1, 1, genres: [28]),
      signal(2, 2, genres: [12]),
      signal(3, 3, genres: [35]),
    ]);

    test('maximum score gives 99 %', () {
      expect(toMatchPercent(2 * 3 + 3 + 1, signals), 99);
    });

    test('zero gives 55 %', () {
      expect(toMatchPercent(0, signals), 55);
    });
  });
}
