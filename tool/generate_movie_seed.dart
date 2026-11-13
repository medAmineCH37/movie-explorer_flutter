// Generates supabase/seed/movies_seed.sql: 100 movies from TMDB.
//
//   dart run tool/generate_movie_seed.dart
//
// Reads TMDB_API_KEY from the environment or from env.json. The app itself
// no longer calls TMDB; this tool only refreshes the sample data.
//
// Selection (deduplicated, in this order): upcoming movies, movies released
// in the last 60 days, 25 top-rated classics, then popular movies until 100.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _target = 100;
const _base = 'https://api.themoviedb.org/3';
const _out = 'supabase/seed/movies_seed.sql';

final _client = http.Client();
late final String _apiKey;

Future<void> main() async {
  _apiKey = _readKey();
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);

  final genres = ((await _get('/genre/movie/list'))['genres'] as List)
      .cast<Map<String, dynamic>>();

  final ids = <int>{};
  void addFrom(
    List<Map<String, dynamic>> movies,
    int limit,
    bool Function(Map<String, dynamic>) keep,
  ) {
    var added = 0;
    for (final m in movies) {
      if (ids.length >= _target || added >= limit) return;
      if (keep(m) && ids.add(m['id'] as int)) added++;
    }
  }

  DateTime? date(Map<String, dynamic> m) =>
      DateTime.tryParse(m['release_date'] as String? ?? '');

  addFrom(
    await _list('upcoming', 8),
    15,
    (m) => date(m)?.isAfter(todayDate) ?? false,
  );
  addFrom(await _list('now_playing', 2), 20, (m) {
    final d = date(m);
    return d != null &&
        !d.isAfter(todayDate) &&
        todayDate.difference(d).inDays <= 60;
  });
  addFrom(await _list('top_rated', 2), 25, (_) => true);
  for (var page = 1; ids.length < _target && page <= 10; page++) {
    addFrom(await _list('popular', 1, startPage: page), _target, (_) => true);
  }
  stdout.writeln('Selected ${ids.length} movies, fetching details…');

  final details = <Map<String, dynamic>>[];
  final idList = ids.toList();
  for (var i = 0; i < idList.length; i += 5) {
    final batch = idList.skip(i).take(5);
    details.addAll(
      await Future.wait(
        batch.map(
          (id) => _get('/movie/$id', {
            'append_to_response': 'credits,videos',
            'include_video_language': 'en,null',
          }),
        ),
      ),
    );
  }

  final movies = <Map<String, Object?>>[];
  final movieGenres = <Map<String, Object?>>[];
  final credits = <Map<String, Object?>>[];

  for (final d in details) {
    final id = d['id'] as int;
    movies.add({
      'id': id,
      'title': _cut(d['title'] as String? ?? 'Untitled', 200),
      'original_title': _cut(d['original_title'] as String? ?? '', 200),
      'tagline': _cut(d['tagline'] as String? ?? '', 300),
      'overview': _cut(d['overview'] as String? ?? '', 5000),
      'release_date': _nullIfEmpty(d['release_date'] as String?),
      'runtime': _positive(d['runtime']),
      'original_language': _language(d['original_language'] as String?),
      'poster_url': _image(d['poster_path'], 'w500'),
      'backdrop_url': _image(d['backdrop_path'], 'w1280'),
      'trailer_youtube_key': _trailer(d),
      'vote_average': ((d['vote_average'] as num? ?? 0) * 10).round() / 10,
      'vote_count': (d['vote_count'] as num? ?? 0).toInt(),
      'popularity': ((d['popularity'] as num? ?? 0) * 1000).round() / 1000,
      'status': d['status'] as String? ?? 'Released',
    });

    for (final g
        in (d['genres'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      movieGenres.add({'movie_id': id, 'genre_id': g['id']});
    }

    final crew = ((d['credits'] as Map?)?['crew'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final directors = <String>[];
    for (final c in crew) {
      final name = c['name'] as String?;
      if (c['job'] == 'Director' && name != null && !directors.contains(name)) {
        directors.add(name);
        credits.add({
          'movie_id': id,
          'kind': 'director',
          'name': _cut(name, 120),
          'character': '',
          'profile_url': _image(c['profile_path'], 'w185'),
          'position': directors.length - 1,
        });
      }
      if (directors.length == 10) break;
    }

    final cast = ((d['credits'] as Map?)?['cast'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .take(15)
        .toList();
    for (var i = 0; i < cast.length; i++) {
      credits.add({
        'movie_id': id,
        'kind': 'cast',
        'name': _cut(cast[i]['name'] as String? ?? 'Unknown', 120),
        'character': _cut(cast[i]['character'] as String? ?? '', 200),
        'profile_url': _image(cast[i]['profile_path'], 'w185'),
        'position': i,
      });
    }
  }

  await File(_out).create(recursive: true);
  await File(_out).writeAsString(
    _sql(
      genres: genres,
      movies: movies,
      movieGenres: movieGenres,
      credits: credits,
      generatedOn: todayDate,
    ),
  );
  stdout.writeln(
    'Wrote $_out: ${movies.length} movies, ${movieGenres.length} genre links, '
    '${credits.length} credits.',
  );
  _client.close();
}

String _sql({
  required List<Map<String, dynamic>> genres,
  required List<Map<String, Object?>> movies,
  required List<Map<String, Object?>> movieGenres,
  required List<Map<String, Object?>> credits,
  required DateTime generatedOn,
}) {
  String data(List<Object?> rows) {
    // One JSON record per line keeps the file compact and diffable.
    final text = '[\n${rows.map(jsonEncode).join(',\n')}\n]';
    if (text.contains(r'$seed$')) throw StateError('Unsafe seed content');
    return '\$seed\$$text\$seed\$::jsonb';
  }

  final day = generatedOn.toIso8601String().substring(0, 10);
  return '''
-- Sample catalogue: ${movies.length} movies generated from TMDB on $day by
-- tool/generate_movie_seed.dart. Run after
-- supabase/migrations/20261112_movies_catalogue.sql. Safe to re-run: seeded
-- movies are updated, their genres and credits replaced; movies added in the
-- app are not touched.
--
-- This product uses the TMDB API but is not endorsed or certified by TMDB.
-- Images are served from image.tmdb.org.

begin;

insert into public.genres (id, name)
select g.id, g.name
from jsonb_to_recordset(${data(genres)}) as g(id smallint, name text)
on conflict (id) do update set name = excluded.name;

insert into public.movies (
  id, title, original_title, tagline, overview, release_date, runtime,
  original_language, poster_url, backdrop_url, trailer_youtube_key,
  vote_average, vote_count, popularity, status
)
select
  m.id, m.title, m.original_title, m.tagline, m.overview, m.release_date,
  m.runtime, m.original_language, m.poster_url, m.backdrop_url,
  m.trailer_youtube_key, m.vote_average, m.vote_count, m.popularity, m.status
from jsonb_to_recordset(${data(movies)}) as m(
  id integer, title text, original_title text, tagline text, overview text,
  release_date date, runtime integer, original_language text,
  poster_url text, backdrop_url text, trailer_youtube_key text,
  vote_average numeric, vote_count integer, popularity numeric, status text
)
on conflict (id) do update set
  title = excluded.title,
  original_title = excluded.original_title,
  tagline = excluded.tagline,
  overview = excluded.overview,
  release_date = excluded.release_date,
  runtime = excluded.runtime,
  original_language = excluded.original_language,
  poster_url = excluded.poster_url,
  backdrop_url = excluded.backdrop_url,
  trailer_youtube_key = excluded.trailer_youtube_key,
  vote_average = excluded.vote_average,
  vote_count = excluded.vote_count,
  popularity = excluded.popularity,
  status = excluded.status;

delete from public.movie_genres
where movie_id in (select (x->>'id')::integer from jsonb_array_elements(${data(movies.map((m) => {'id': m['id']}).toList())}) x);

insert into public.movie_genres (movie_id, genre_id)
select mg.movie_id, mg.genre_id
from jsonb_to_recordset(${data(movieGenres)}) as mg(movie_id integer, genre_id smallint)
on conflict do nothing;

delete from public.movie_credits
where movie_id in (select (x->>'id')::integer from jsonb_array_elements(${data(movies.map((m) => {'id': m['id']}).toList())}) x);

insert into public.movie_credits (movie_id, kind, name, character, profile_url, position)
select c.movie_id, c.kind, c.name, c.character, c.profile_url, c.position
from jsonb_to_recordset(${data(credits)}) as c(
  movie_id integer, kind text, name text, character text,
  profile_url text, position smallint
);

commit;
''';
}

String _readKey() {
  final fromEnv = Platform.environment['TMDB_API_KEY'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  final file = File('env.json');
  if (file.existsSync()) {
    final key = (jsonDecode(file.readAsStringSync()) as Map)['TMDB_API_KEY'];
    if (key is String && key.isNotEmpty && !key.startsWith('YOUR_')) return key;
  }
  stderr.writeln('TMDB_API_KEY not found (environment or env.json).');
  exit(64);
}

Future<Map<String, dynamic>> _get(
  String path, [
  Map<String, String> query = const {},
]) async {
  final uri = Uri.parse('$_base$path').replace(
    queryParameters: {'api_key': _apiKey, 'language': 'en-US', ...query},
  );
  for (var attempt = 1; ; attempt++) {
    final response = await _client.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    if (response.statusCode == 429 && attempt < 5) {
      await Future<void>.delayed(Duration(seconds: attempt * 2));
      continue;
    }
    throw HttpException('TMDB $path failed with ${response.statusCode}');
  }
}

Future<List<Map<String, dynamic>>> _list(
  String slug,
  int pages, {
  int startPage = 1,
}) async {
  final all = <Map<String, dynamic>>[];
  for (var p = startPage; p < startPage + pages; p++) {
    final data = await _get('/movie/$slug', {'page': '$p'});
    all.addAll((data['results'] as List).cast<Map<String, dynamic>>());
  }
  return all;
}

String _cut(String value, int max) {
  final text = value.trim();
  return text.length <= max ? text : text.substring(0, max).trimRight();
}

String? _nullIfEmpty(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();

int? _positive(Object? value) {
  final n = (value as num?)?.toInt();
  return n == null || n <= 0 || n > 1000 ? null : n;
}

String? _language(String? code) =>
    code != null && RegExp(r'^[a-z]{2}$').hasMatch(code) ? code : null;

String? _image(Object? path, String size) {
  if (path is! String || path.isEmpty) return null;
  return 'https://image.tmdb.org/t/p/$size$path';
}

String? _trailer(Map<String, dynamic> details) {
  final videos = ((details['videos'] as Map?)?['results'] as List? ?? const [])
      .cast<Map<String, dynamic>>();
  int rank(Map<String, dynamic> v) {
    final key = v['key'] as String? ?? '';
    if (v['site'] != 'YouTube' ||
        !RegExp(r'^[A-Za-z0-9_-]{6,20}$').hasMatch(key)) {
      return 99;
    }
    final official = v['official'] == true;
    if (v['type'] == 'Trailer') return official ? 0 : 1;
    if (v['type'] == 'Teaser') return official ? 2 : 3;
    return 99;
  }

  Map<String, dynamic>? best;
  for (final v in videos) {
    if (rank(v) < (best == null ? 99 : rank(best))) best = v;
  }
  return best?['key'] as String?;
}
