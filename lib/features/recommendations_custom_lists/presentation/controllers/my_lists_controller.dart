import 'package:flutter/foundation.dart';

import '../../data/custom_list_repository.dart';
import '../../domain/models/custom_list.dart';

enum ListFilter { all, private, public }

enum ListSort { recent, name, size }

class MyListsController extends ChangeNotifier {
  MyListsController({CustomListRepository? repository})
    : repository = repository ?? CustomListRepository();

  final CustomListRepository repository;

  bool loading = false;
  String? error;
  List<CustomList> lists = [];
  ListFilter filter = ListFilter.all;
  ListSort sort = ListSort.recent;

  List<CustomList> get visible {
    final filtered = lists.where(
      (l) => switch (filter) {
        ListFilter.all => true,
        ListFilter.private => !l.isPublic,
        ListFilter.public => l.isPublic,
      },
    );
    return filtered.toList()..sort(
      (a, b) => switch (sort) {
        ListSort.recent => (b.updatedAt ?? DateTime(2000)).compareTo(
          a.updatedAt ?? DateTime(2000),
        ),
        ListSort.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        ListSort.size => b.movieCount.compareTo(a.movieCount),
      },
    );
  }

  void setFilter(ListFilter value) {
    filter = value;
    notifyListeners();
  }

  void setSort(ListSort value) {
    sort = value;
    notifyListeners();
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      lists = await repository.getMyLists();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Returns the created list, or throws a user-facing error.
  Future<CustomList> create(
    String name,
    String description,
    bool isPublic,
  ) async {
    final list = await repository.createList(
      name: name,
      description: description,
      isPublic: isPublic,
    );
    await load();
    return list;
  }
}
