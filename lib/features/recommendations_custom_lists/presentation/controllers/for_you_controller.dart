import 'package:flutter/foundation.dart';

import '../../data/custom_list_repository.dart';
import '../../data/recommendation_service.dart';
import '../../domain/models/custom_list.dart';
import '../../domain/models/recommended_movie.dart';
import '../../domain/models/tmdb_candidate.dart';

class GenreRow {
  const GenreRow(this.id, this.name, this.movies);
  final int id;
  final String name;
  final List<RecommendedMovie> movies;
}

class ForYouController extends ChangeNotifier {
  ForYouController({
    RecommendationService? service,
    CustomListRepository? lists,
  }) : _lists = lists ?? CustomListRepository(),
       _service = service ?? RecommendationService(lists: lists);

  final RecommendationService _service;
  final CustomListRepository _lists;

  /// Action, Comedy, Science Fiction: rows shown when the user has no favorite genre.
  static const List<int> _defaultGenres = [28, 35, 878];

  bool loading = false;
  String? error;
  RecommendationsResult? recommendations;
  List<TmdbCandidate> trending = [];
  List<GenreRow> genreRows = [];
  List<CustomList> myLists = [];

  bool get signedIn => _lists.currentUserId != null;
  bool get isPersonal =>
      recommendations?.source == RecommendationSource.personal;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final trendingFuture = _service.tmdb.trending();
      final recoFuture = _service.forCurrentUser(limit: 20);
      final listsFuture = signedIn
          ? _lists.getMyLists().catchError((Object _) => <CustomList>[])
          : Future.value(<CustomList>[]);
      trending = await trendingFuture;
      recommendations = await recoFuture;
      myLists = await listsFuture;
      genreRows = await _loadGenreRows(recommendations!.topGenres);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<List<GenreRow>> _loadGenreRows(List<int> topGenres) async {
    final names = await _service.tmdb.genreNames();
    final ids = topGenres.isNotEmpty ? topGenres : _defaultGenres;
    final rows = await Future.wait(
      ids.map((id) async {
        try {
          final movies = await _service.tmdb.discoverByGenres([id]);
          return GenreRow(
            id,
            names[id] ?? 'Movies',
            movies.map((m) => RecommendedMovie(movie: m)).toList(),
          );
        } catch (_) {
          return GenreRow(id, names[id] ?? 'Movies', const []);
        }
      }),
    );
    return rows.where((r) => r.movies.isNotEmpty).toList();
  }
}
