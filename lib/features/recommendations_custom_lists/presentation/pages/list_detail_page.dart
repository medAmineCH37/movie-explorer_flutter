import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../domain/list_rules.dart';
import '../../domain/models/custom_list.dart';
import '../controllers/list_detail_controller.dart';
import '../widgets/add_movies_sheet.dart';
import '../widgets/list_form_sheet.dart';
import '../widgets/movie_rail.dart';
import '../widgets/reco_ui.dart';

class ListDetailPage extends StatefulWidget {
  const ListDetailPage({required this.listId, super.key});

  final int listId;

  @override
  State<ListDetailPage> createState() => _ListDetailPageState();
}

class _ListDetailPageState extends State<ListDetailPage> {
  late final ListDetailController _controller = ListDetailController(
    widget.listId,
  );

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    try {
      await action();
      if (mounted) showRecoSnack(context, success);
    } catch (e) {
      if (mounted) showRecoSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _edit(CustomList list) async {
    final mine = await _controller.repository.getMyLists().catchError(
      (Object _) => <CustomList>[],
    );
    if (!mounted) return;
    final form = await showListFormSheet(
      context,
      initial: list,
      otherNames: mine.where((l) => l.id != list.id).map((l) => l.name),
    );
    if (form == null) return;
    await _run(
      () => _controller.update(form.name, form.description, form.isPublic),
      'List updated',
    );
  }

  Future<void> _delete(CustomList list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this list?'),
        content: Text(
          '"${list.name}" and its ${list.movieCount} movies will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _controller.delete();
      if (!mounted) return;
      showRecoSnack(context, 'List deleted');
      context.pop();
    } catch (e) {
      if (mounted) showRecoSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _share(CustomList list) async {
    final lines = [
      '🎬 ${list.name} — ${list.movieCount} movies on Movie Explorer',
      if (list.description.isNotEmpty) list.description,
      for (final (i, m) in list.movies.take(20).indexed) '${i + 1}. ${m.title}',
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (mounted) {
      showRecoSnack(context, 'List copied — paste it anywhere to share');
    }
  }

  Future<void> _addMovies(CustomList list) async {
    await showAddMoviesSheet(
      context,
      initialIds: list.movies.map((m) => m.movieId).toSet(),
      onAdd: _controller.addMovie,
    );
    await _controller.loadRecommendations();
  }

  void _movieActions(ListMovie movie) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('View details'),
              onTap: () {
                Navigator.pop(sheet);
                openMovie(context, movie.movieId);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.remove_circle_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text('Remove from this list'),
              onTap: () {
                Navigator.pop(sheet);
                _run(() async {
                  await _controller.removeMovie(movie.movieId);
                  await _controller.loadRecommendations();
                }, 'Removed ${movie.title}');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final c = _controller;
        final list = c.list;
        if (c.loading && list == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (c.error != null || c.notFound || list == null) {
          return Scaffold(
            appBar: AppBar(),
            body: c.notFound
                ? const Center(
                    child: Text('This list does not exist or is private.'),
                  )
                : ErrorRetry(
                    message: c.error ?? 'Unknown error',
                    onRetry: c.load,
                  ),
          );
        }
        return Scaffold(
          floatingActionButton:
              c.isOwner && list.movieCount < ListRules.maxMoviesPerList
              ? FloatingActionButton.extended(
                  onPressed: () => _addMovies(list),
                  icon: const Icon(Icons.add),
                  label: const Text('Add movies'),
                )
              : null,
          body: RefreshIndicator(
            onRefresh: c.load,
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 320,
                  actions: [
                    IconButton(
                      tooltip: 'Share',
                      onPressed: () => _share(list),
                      icon: const Icon(Icons.ios_share),
                    ),
                    if (c.isOwner)
                      PopupMenuButton<String>(
                        onSelected: (v) =>
                            v == 'edit' ? _edit(list) : _delete(list),
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit list'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete list'),
                          ),
                        ],
                      ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: _Header(list: list, isOwner: c.isOwner),
                  ),
                ),
                if (c.recommendationsLoading ||
                    (c.recommendations?.results.isNotEmpty ?? false)) ...[
                  const SliverToBoxAdapter(
                    child: SectionHeader(
                      'More like this list',
                      subtitle: 'Based on the movies in this list',
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: MovieRail(
                      items: c.recommendations?.results ?? const [],
                      loading: c.recommendationsLoading,
                    ),
                  ),
                ],
                SliverToBoxAdapter(
                  child: SectionHeader(
                    'Movies',
                    subtitle: c.isOwner
                        ? '${list.movieCount}/${ListRules.maxMoviesPerList} · long press to remove'
                        : '${list.movieCount} movies',
                  ),
                ),
                if (list.movies.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        c.isOwner
                            ? 'This list is empty. Tap “Add movies” to start.'
                            : 'This list is empty.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 140,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 10,
                            childAspectRatio: 2 / 3,
                          ),
                      itemCount: list.movies.length,
                      itemBuilder: (context, i) {
                        final movie = list.movies[i];
                        return GestureDetector(
                          onTap: () => openMovie(context, movie.movieId),
                          onLongPress: c.isOwner
                              ? () => _movieActions(movie)
                              : null,
                          child: PosterImage(url: movie.posterUrl),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.list, required this.isOwner});

  final CustomList list;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: 0.45,
          child: ListCover(posters: list.previewPosters, radius: 0),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [background.withValues(alpha: 0.3), background],
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 96,
                height: 144,
                child: ListCover(posters: list.previewPosters),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      list.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Chip(
                          icon: list.isPublic
                              ? Icons.public
                              : Icons.lock_outline,
                          label: list.isPublic ? 'Public' : 'Private',
                        ),
                        _Chip(
                          icon: Icons.movie_outlined,
                          label: '${list.movieCount}',
                        ),
                        if (!isOwner && list.ownerName != null)
                          _Chip(
                            icon: Icons.person_outline,
                            label: list.ownerName!,
                          ),
                      ],
                    ),
                    if (list.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        list.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
