import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/reco_tmdb_service.dart';
import '../../domain/list_rules.dart';
import '../../domain/models/tmdb_candidate.dart';
import 'reco_ui.dart';

/// Search TMDB and add movies to a list. [onAdd] returns an error message or null.
Future<void> showAddMoviesSheet(
  BuildContext context, {
  required Set<int> initialIds,
  required Future<String?> Function(TmdbCandidate movie) onAdd,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => _AddMoviesSheet(initialIds: initialIds, onAdd: onAdd),
  );
}

class _AddMoviesSheet extends StatefulWidget {
  const _AddMoviesSheet({required this.initialIds, required this.onAdd});

  final Set<int> initialIds;
  final Future<String?> Function(TmdbCandidate movie) onAdd;

  @override
  State<_AddMoviesSheet> createState() => _AddMoviesSheetState();
}

class _AddMoviesSheetState extends State<_AddMoviesSheet> {
  final RecoTmdbService _tmdb = RecoTmdbService();
  late final Set<int> _inList = {...widget.initialIds};
  final Set<int> _busy = {};
  Timer? _debounce;
  List<TmdbCandidate> _results = [];
  bool _loading = false;
  String? _error;
  int _request = 0;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _tmdb.dispose();
    super.dispose();
  }

  void _onQuery(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    _query = query;
    final request = ++_request;
    setState(() {
      _loading = query.trim().isNotEmpty;
      _error = null;
      if (query.trim().isEmpty) _results = [];
    });
    if (query.trim().isEmpty) return;
    try {
      final results = await _tmdb.search(query);
      if (mounted && request == _request) setState(() => _results = results);
    } catch (e) {
      if (mounted && request == _request) setState(() => _error = e.toString());
    }
    if (mounted && request == _request) setState(() => _loading = false);
  }

  Future<void> _add(TmdbCandidate movie) async {
    setState(() => _busy.add(movie.id));
    final error = await widget.onAdd(movie);
    if (!mounted) return;
    setState(() {
      _busy.remove(movie.id);
      if (error == null) _inList.add(movie.id);
    });
    showRecoSnack(
      context,
      error ?? 'Added ${movie.title}',
      error: error != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: true,
              onChanged: _onQuery,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search a movie to add',
                prefixIcon: const Icon(Icons.search),
                helperText:
                    '${_inList.length}/${ListRules.maxMoviesPerList} movies in this list',
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _error != null
                ? ErrorRetry(message: _error!, onRetry: () => _search(_query))
                : _results.isEmpty
                ? const Center(
                    child: Text(
                      'Type a title to find movies',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final movie = _results[i];
                      final added = _inList.contains(movie.id);
                      final busy = _busy.contains(movie.id);
                      return ListTile(
                        leading: PosterImage(
                          url: movie.posterUrl,
                          width: 40,
                          height: 60,
                          radius: 6,
                        ),
                        title: Text(
                          movie.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Row(
                          children: [
                            RatingLabel(movie.voteAverage),
                            const SizedBox(width: 8),
                            Text(movie.year),
                          ],
                        ),
                        trailing: busy
                            ? const SizedBox.square(
                                dimension: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : IconButton.filledTonal(
                                onPressed: added ? null : () => _add(movie),
                                icon: Icon(added ? Icons.check : Icons.add),
                                tooltip: added ? 'In this list' : 'Add',
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
