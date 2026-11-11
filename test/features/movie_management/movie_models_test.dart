import 'package:flutter_test/flutter_test.dart';
import 'package:movie_explorer/features/movie_management/data/models/movie.dart';
import 'package:movie_explorer/features/movie_management/data/models/movie_category.dart';
import 'package:movie_explorer/features/movie_management/data/models/movie_details.dart';
import 'package:movie_explorer/features/movie_management/data/models/movie_draft.dart';
import 'package:movie_explorer/features/movie_management/data/models/movie_page.dart';
import 'package:movie_explorer/features/movie_management/data/models/movie_search_query.dart';
import 'package:movie_explorer/features/movie_management/presentation/movie_formatters.dart';

void main() {
  group('Movie.fromJson', () {
    test('reads search_movies rows', () {
      final m = Movie.fromJson({
        'id': 27205,
        'title': 'Inception',
        'overview': 'Dreams.',
        'release_date': '2010-07-15',
        'runtime': 148,
        'original_language': 'en',
        'poster_url': 'https://image.tmdb.org/t/p/w500/p.jpg',
        'backdrop_url': null,
        'vote_average': 8.4,
        'vote_count': 37000,
        'genres': ['Action', 'Science Fiction'],
        'total_count': 100,
      });
      expect(m.id, 27205);
      expect(m.releaseYear, '2010');
      expect(m.posterUrl, 'https://image.tmdb.org/t/p/w500/p.jpg');
      expect(m.backdropUrl, isNull);
      expect(m.genres, ['Action', 'Science Fiction']);
      expect(m.voteCount, 37000);
    });

    test('reads embedded genres and string ratings', () {
      final m = Movie.fromJson({
        'id': 1,
        'title': 'X',
        'vote_average': '6.5',
        'release_date': null,
        'movie_genres': [
          {
            'genres': {'name': 'Drama'},
          },
        ],
      });
      expect(m.voteAverage, 6.5);
      expect(m.releaseYear, isNull);
      expect(m.genres, ['Drama']);
    });

    test('keeps legacy TMDB image paths working', () {
      const m = Movie(
        id: 1,
        title: 'X',
        overview: '',
        posterPath: '/abc.jpg',
        backdropPath: null,
        voteAverage: 0,
        releaseDate: '',
      );
      expect(m.posterUrl, 'https://image.tmdb.org/t/p/w500/abc.jpg');
    });
  });

  test('MovieDetails.fromJson orders credits and genres', () {
    final d = MovieDetails.fromJson({
      'id': 5,
      'title': 'Film',
      'original_title': 'Le Film',
      'tagline': ' Big. ',
      'status': 'Released',
      'original_language': 'fr',
      'trailer_youtube_key': 'dQw4w9WgXcQ',
      'created_by': 'u1',
      'movie_genres': [
        {
          'genres': {'id': 35, 'name': 'Comedy'},
        },
        {
          'genres': {'id': 18, 'name': 'Drama'},
        },
      ],
      'movie_credits': [
        {'kind': 'cast', 'name': 'B', 'character': 'Two', 'position': 1},
        {'kind': 'director', 'name': 'Dir', 'position': 0},
        {'kind': 'cast', 'name': 'A', 'character': 'One', 'position': 0},
      ],
    });
    expect(d.genres.map((g) => g.name), ['Comedy', 'Drama']);
    expect(d.movie.genres, ['Comedy', 'Drama']);
    expect(d.directors, ['Dir']);
    expect(d.cast.map((c) => c.name), ['A', 'B']);
    expect(d.tagline, 'Big.');
    expect(d.languageName, 'French');
    expect(
      d.trailer?.watchUrl.toString(),
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    );
    expect(d.createdBy, 'u1');
  });

  test('MovieVideo.parseKey accepts YouTube links and ids', () {
    const key = 'dQw4w9WgXcQ';
    for (final input in [
      key,
      'https://www.youtube.com/watch?v=$key&t=10',
      'youtube.com/watch?v=$key',
      'https://youtu.be/$key',
      'https://www.youtube.com/embed/$key',
      'https://m.youtube.com/shorts/$key',
    ]) {
      expect(MovieVideo.parseKey(input), key, reason: input);
    }
    expect(MovieVideo.parseKey('https://vimeo.com/123456'), isNull);
    expect(MovieVideo.parseKey('not a video!'), isNull);
    expect(MovieVideo.parseKey(''), isNull);
  });

  group('MovieDraft', () {
    test('validates every field', () {
      final draft = MovieDraft(
        title: '  ',
        runtime: '0',
        rating: '11',
        posterUrl: 'http://insecure.example/p.jpg',
        trailer: 'https://vimeo.com/1',
        directors: List.filled(11, 'Name').join(','),
        cast: List.generate(31, (i) => CastDraft(name: 'Actor $i')),
      );
      expect(
        draft.validate().keys,
        containsAll([
          'title',
          'runtime',
          'rating',
          'posterUrl',
          'trailer',
          'directors',
          'cast',
        ]),
      );
      expect(MovieDraft(title: 'Ok').validate(), isEmpty);
      expect(MovieDraft.validateRating('7,5'), isNull);
    });

    test('builds save_movie parameters', () {
      final params = MovieDraft(
        title: ' New ',
        releaseDate: DateTime(2026, 3, 9),
        runtime: ' 95 ',
        language: 'fr',
        rating: '7,5',
        trailer: 'https://youtu.be/dQw4w9WgXcQ',
        genreIds: {35, 18},
        directors: 'Ann, , Bo ',
        cast: [
          CastDraft(name: 'Cat', character: 'Herself'),
          CastDraft(name: '  '),
        ],
      ).toRpcParams(null);

      expect(params['p_id'], isNull);
      final movie = params['p_movie'] as Map<String, dynamic>;
      expect(movie['title'], 'New');
      expect(movie['release_date'], '2026-03-09');
      expect(movie['runtime'], '95');
      expect(movie['vote_average'], '7.5');
      expect(movie['trailer_youtube_key'], 'dQw4w9WgXcQ');
      expect(params['p_genre_ids'], [18, 35]);
      expect(params['p_directors'], ['Ann', 'Bo']);
      expect(params['p_cast'], [
        {'name': 'Cat', 'character': 'Herself'},
      ]);
    });

    test('round-trips from details', () {
      final draft = MovieDraft.fromDetails(
        MovieDetails.fromJson({
          'id': 1,
          'title': 'T',
          'release_date': '2001-02-03',
          'runtime': 100,
          'vote_average': 6,
          'status': 'Rumored',
          'trailer_youtube_key': 'dQw4w9WgXcQ',
          'movie_genres': [
            {
              'genres': {'id': 18, 'name': 'Drama'},
            },
          ],
          'movie_credits': [
            {'kind': 'director', 'name': 'D1', 'position': 0},
            {'kind': 'director', 'name': 'D2', 'position': 1},
            {'kind': 'cast', 'name': 'A', 'character': 'R', 'position': 0},
          ],
        }),
      );
      expect(draft.releaseDate, DateTime(2001, 2, 3));
      expect(draft.rating, '6.0');
      expect(draft.status, 'Rumored');
      expect(draft.genreIds, {18});
      expect(draft.directors, 'D1, D2');
      expect(draft.cast.single.character, 'R');
      expect(draft.trailer, 'dQw4w9WgXcQ');
    });
  });

  group('MovieSearchQuery', () {
    test('maps to search_movies parameters and counts filters', () {
      const q = MovieSearchQuery(
        text: '  dune ',
        genreIds: {18},
        yearFrom: 2000,
        minRating: 7,
        language: 'en',
        category: MovieCategory.topRated,
        sort: MovieSort.newest,
      );
      final p = q.toParams(page: 2, pageSize: 20);
      expect(p['p_query'], 'dune');
      expect(p['p_genre_ids'], [18]);
      expect(p['p_year_from'], 2000);
      expect(p['p_year_to'], isNull);
      expect(p['p_category'], 'top_rated');
      expect(p['p_sort'], 'newest');
      expect(p['p_page'], 2);
      expect(q.activeFilterCount, 4);

      final cleared = q.clearFilters();
      expect(cleared.activeFilterCount, 0);
      expect(cleared.text, '  dune ');
      expect(cleared.sort, MovieSort.newest);
      expect(
        const MovieSearchQuery().toParams(page: 1, pageSize: 20)['p_query'],
        isNull,
      );
    });
  });

  test('MoviePage pagination', () {
    final page = MoviePage.fromRows(
      [
        {'id': 1, 'title': 'A', 'total_count': 41},
      ],
      page: 2,
      pageSize: 20,
    );
    expect(page.total, 41);
    expect(page.totalPages, 3);
    expect(page.hasMore, isTrue);
    expect(
      MoviePage.fromRows(const [], page: 1, pageSize: 20).hasMore,
      isFalse,
    );
  });

  test('MovieFormatters', () {
    expect(MovieFormatters.runtime(148), '2h 28m');
    expect(MovieFormatters.runtime(45), '45m');
    expect(MovieFormatters.runtime(null), isNull);
    expect(MovieFormatters.compactCount(12345), '12.3k');
    expect(MovieFormatters.date('2024-03-01'), '1 Mar 2024');
  });
}
