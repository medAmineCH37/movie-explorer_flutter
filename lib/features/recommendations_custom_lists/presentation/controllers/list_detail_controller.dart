import 'package:flutter/foundation.dart';

import '../../data/custom_list_repository.dart';
import '../../data/list_changes.dart';
import '../../data/recommendation_service.dart';
import '../../domain/models/custom_list.dart';
import '../../domain/models/recommended_movie.dart';
import '../../domain/models/tmdb_candidate.dart';

class ListDetailController extends ChangeNotifier {
  ListDetailController(
    this.listId, {
    CustomListRepository? repository,
    RecommendationService? service,
  }) : repository = repository ?? CustomListRepository(),
       _service = service ?? RecommendationService(lists: repository) {
    ListChanges.instance.addListener(_onListsChanged);
  }

  bool _disposed = false;
  bool _deleted = false;

  void _onListsChanged() {
    if (!loading && !_deleted) load();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ListChanges.instance.removeListener(_onListsChanged);
    super.dispose();
  }

  final int listId;
  final CustomListRepository repository;
  final RecommendationService _service;

  bool loading = false;
  bool notFound = false;
  String? error;
  CustomList? list;
  RecommendationsResult? recommendations;
  bool recommendationsLoading = false;

  bool get isOwner => list != null && list!.ownerId == repository.currentUserId;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      list = await repository.getList(listId);
      notFound = list == null;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
    if (list != null) await loadRecommendations();
  }

  Future<void> loadRecommendations() async {
    final current = list;
    if (current == null || current.movies.isEmpty) {
      recommendations = null;
      notifyListeners();
      return;
    }
    recommendationsLoading = true;
    notifyListeners();
    try {
      recommendations = await _service.forList(current, limit: 15);
    } catch (_) {
      recommendations = null; // recommendations never block the list
    } finally {
      recommendationsLoading = false;
      notifyListeners();
    }
  }

  /// Returns an error message, or null when the movie was added.
  Future<String?> addMovie(TmdbCandidate movie) async {
    final current = list;
    if (current == null) return 'List not loaded.';
    try {
      final added = ListMovie.fromCandidate(movie);
      await repository.addMovie(current, added);
      list = current.copyWith(movies: [added, ...current.movies]);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> removeMovie(int movieId) async {
    final current = list!;
    await repository.removeMovie(listId, movieId);
    list = current.copyWith(
      movies: current.movies.where((m) => m.movieId != movieId).toList(),
    );
    notifyListeners();
  }

  Future<void> update(String name, String description, bool isPublic) async {
    await repository.updateList(
      listId,
      name: name,
      description: description,
      isPublic: isPublic,
    );
    list = list!.copyWith(
      name: name,
      description: description,
      isPublic: isPublic,
    );
    notifyListeners();
  }

  Future<void> delete() {
    _deleted = true;
    return repository.deleteList(listId);
  }
}
