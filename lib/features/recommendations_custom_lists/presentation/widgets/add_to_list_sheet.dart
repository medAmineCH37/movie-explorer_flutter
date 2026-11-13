import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/custom_list_repository.dart';
import '../../data/reco_tmdb_service.dart';
import '../../domain/list_rules.dart';
import '../../domain/models/custom_list.dart';
import '../../domain/models/tmdb_candidate.dart';
import 'list_form_sheet.dart';
import 'reco_ui.dart';

/// Bottom sheet to add/remove [movie] in the user's lists.
Future<void> showAddToListSheet(
  BuildContext context,
  TmdbCandidate movie,
) async {
  final repository = CustomListRepository();
  if (repository.currentUserId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Sign in to create your lists.'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Sign in',
          onPressed: () => context.push('/login'),
        ),
      ),
    );
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => _AddToListSheet(movie: movie, repository: repository),
  );
}

/// "Add to list" button for the movie details page (Module 2).
class AddToListButton extends StatefulWidget {
  const AddToListButton({required this.movieId, super.key});

  final int movieId;

  @override
  State<AddToListButton> createState() => _AddToListButtonState();
}

class _AddToListButtonState extends State<AddToListButton> {
  bool _loading = false;

  Future<void> _open() async {
    setState(() => _loading = true);
    final tmdb = RecoTmdbService();
    try {
      final movie = await tmdb.details(widget.movieId);
      if (mounted) await showAddToListSheet(context, movie);
    } catch (e) {
      if (mounted) showRecoSnack(context, e.toString(), error: true);
    } finally {
      tmdb.dispose();
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _open,
        icon: _loading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.playlist_add),
        label: const Text('Add to a list'),
      ),
    );
  }
}

class _AddToListSheet extends StatefulWidget {
  const _AddToListSheet({required this.movie, required this.repository});

  final TmdbCandidate movie;
  final CustomListRepository repository;

  @override
  State<_AddToListSheet> createState() => _AddToListSheetState();
}

class _AddToListSheetState extends State<_AddToListSheet> {
  List<CustomList> _lists = [];
  Set<int> _containing = {};
  final Set<int> _busy = {};
  bool _loading = true;
  String? _error;

  CustomListRepository get _repo => widget.repository;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.getMyLists(),
        _repo.myListIdsContaining(widget.movie.id),
      ]);
      _lists = results[0] as List<CustomList>;
      _containing = results[1] as Set<int>;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle(CustomList list) async {
    final inList = _containing.contains(list.id);
    setState(() => _busy.add(list.id));
    try {
      if (inList) {
        await _repo.removeMovie(list.id, widget.movie.id);
        _containing.remove(list.id);
      } else {
        await _repo.addMovie(list, ListMovie.fromCandidate(widget.movie));
        _containing.add(list.id);
      }
      _lists = [
        for (final l in _lists)
          l.id == list.id
              ? l.copyWith(movieCount: l.movieCount + (inList ? -1 : 1))
              : l,
      ];
      if (mounted) {
        showRecoSnack(
          context,
          inList ? 'Removed from ${list.name}' : 'Added to ${list.name}',
        );
      }
    } catch (e) {
      if (mounted) showRecoSnack(context, e.toString(), error: true);
    }
    if (mounted) setState(() => _busy.remove(list.id));
  }

  Future<void> _createAndAdd() async {
    final limit = ListRules.canCreateList(_lists.length);
    if (limit != null) {
      showRecoSnack(context, limit, error: true);
      return;
    }
    final form = await showListFormSheet(
      context,
      otherNames: _lists.map((l) => l.name),
    );
    if (form == null) return;
    try {
      final list = await _repo.createList(
        name: form.name,
        description: form.description,
        isPublic: form.isPublic,
      );
      await _repo.addMovie(list, ListMovie.fromCandidate(widget.movie));
      await _load();
      if (mounted) showRecoSnack(context, 'Added to ${list.name}');
    } catch (e) {
      if (mounted) showRecoSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: PosterImage(
              url: movie.posterUrl,
              width: 40,
              height: 60,
              radius: 6,
            ),
            title: Text(
              movie.title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('Save to your lists'),
          ),
          const Divider(height: 1),
          Flexible(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _error != null
                ? ErrorRetry(message: _error!, onRetry: _load)
                : ListView(
                    shrinkWrap: true,
                    children: [
                      ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.add)),
                        title: const Text('New list'),
                        subtitle: Text(
                          '${_lists.length}/${ListRules.maxLists} lists',
                        ),
                        onTap: _createAndAdd,
                      ),
                      for (final list in _lists)
                        CheckboxListTile(
                          value: _containing.contains(list.id),
                          onChanged: _busy.contains(list.id)
                              ? null
                              : (_) => _toggle(list),
                          secondary: SizedBox(
                            width: 40,
                            height: 60,
                            child: ListCover(
                              posters: list.previewPosters,
                              radius: 6,
                            ),
                          ),
                          title: Text(
                            list.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Row(
                            children: [
                              Icon(
                                list.isPublic
                                    ? Icons.public
                                    : Icons.lock_outline,
                                size: 14,
                                color: Colors.white54,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${list.movieCount}/${ListRules.maxMoviesPerList} movies',
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
