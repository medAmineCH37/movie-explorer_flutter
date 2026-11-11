import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../movie_management/data/models/languages.dart';
import '../../../movie_management/data/models/movie.dart';
import '../../../movie_management/data/models/movie_search_query.dart';
import '../../../movie_management/data/repositories/supabase_movies_repository.dart';
import '../../../movie_management/domain/repositories/movies_repository.dart';
import '../../../movie_management/presentation/movie_actions.dart';
import '../../../movie_management/presentation/movie_formatters.dart';
import '../../../movie_management/presentation/widgets/movie_card.dart';
import '../../../movie_management/presentation/widgets/movie_poster_image.dart';
import '../../../movie_management/presentation/widgets/movie_state_views.dart';
import '../controllers/discovery_controller.dart';
import '../widgets/discovery_filters_sheet.dart';

/// Movie Discovery: search the catalogue, filter, sort, and add, edit or
/// delete movies.
class MovieDiscoveryPage extends StatefulWidget {
  const MovieDiscoveryPage({super.key, this.repository});

  final MoviesRepository? repository;

  @override
  State<MovieDiscoveryPage> createState() => _MovieDiscoveryPageState();
}

class _MovieDiscoveryPageState extends State<MovieDiscoveryPage> {
  late final MoviesRepository _repository;
  late final DiscoveryController _controller;
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupabaseMoviesRepository();
    _controller = DiscoveryController(repository: _repository)..init();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _controller.setText(text),
    );
    setState(() {}); // clear button visibility
  }

  Future<void> _openFilters() async {
    final next = await showDiscoveryFilters(
      context,
      query: _controller.query,
      genres: _controller.genres,
      languages: _controller.languages,
    );
    if (next != null) await _controller.applyQuery(next);
  }

  Future<void> _open(Movie movie) async {
    await context.push('/movie/${movie.id}');
    // The movie may have been edited or deleted on its page.
    if (mounted) await _controller.search();
  }

  Future<void> _add() async {
    await MovieActions.openEditor(context, _repository);
    if (mounted) await _controller.search();
  }

  Future<void> _edit(Movie movie) async {
    final saved = await MovieActions.openEditor(
      context,
      _repository,
      movieId: movie.id,
    );
    if (saved && mounted) {
      MovieActions.showMessage(context, '"${movie.title}" updated.');
      await _controller.search();
    }
  }

  Future<void> _delete(Movie movie) async {
    final deleted = await MovieActions.delete(
      context,
      _repository,
      movieId: movie.id,
      title: movie.title,
    );
    if (deleted) _controller.movieDeleted(movie.id);
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.extentAfter < 500 && _controller.loadMoreError == null) {
      _controller.loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Discover',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Add movie'),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final c = _controller;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _search,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (text) {
                    _debounce?.cancel();
                    _controller.setText(text);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by title',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _search.clear();
                              _onSearchChanged('');
                            },
                          ),
                  ),
                ),
              ),
              _Toolbar(controller: c, onFilters: _openFilters),
              _ActiveFilters(controller: c),
              if (c.isLoading) const LinearProgressIndicator(minHeight: 2),
              Expanded(child: _results(c)),
            ],
          );
        },
      ),
    );
  }

  Widget _results(DiscoveryController c) {
    if (!c.hasSearched && c.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (c.error != null && c.movies.isEmpty) {
      return Center(
        child: MovieLoadError(message: c.error!, onRetry: c.search),
      );
    }
    if (c.movies.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MovieEmptyState(
              message: 'No movies match your search.',
              icon: Icons.search_off,
            ),
            if (c.query.activeFilterCount > 0)
              OutlinedButton(
                onPressed: c.clearFilters,
                child: const Text('Clear filters'),
              ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: RefreshIndicator(
        onRefresh: c.search,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: c.movies.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == c.movies.length) return _footer(c);
            final movie = c.movies[index];
            return DiscoveryMovieTile(
              key: ValueKey('discover-${movie.id}'),
              movie: movie,
              onTap: () => _open(movie),
              onEdit: () => _edit(movie),
              onDelete: () => _delete(movie),
            );
          },
        ),
      ),
    );
  }

  Widget _footer(DiscoveryController c) {
    if (c.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (c.loadMoreError != null) {
      return MovieLoadError(message: c.loadMoreError!, onRetry: c.loadMore);
    }
    return const SizedBox.shrink();
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.controller, required this.onFilters});

  final DiscoveryController controller;
  final VoidCallback onFilters;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final count = c.query.activeFilterCount;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: onFilters,
            icon: Badge(
              isLabelVisible: count > 0,
              label: Text('$count'),
              child: const Icon(Icons.tune),
            ),
            label: const Text('Filters'),
          ),
          Flexible(
            child: PopupMenuButton<MovieSort>(
              tooltip: 'Sort movies',
              initialValue: c.query.sort,
              onSelected: c.setSort,
              itemBuilder: (_) => [
                for (final sort in MovieSort.values)
                  PopupMenuItem(value: sort, child: Text(sort.label)),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sort, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        (c.query.sort ?? MovieSort.popularity).label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: theme.colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (c.hasSearched)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                c.total == 1 ? '1 movie' : '${c.total} movies',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.controller});

  final DiscoveryController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final q = c.query;
    if (q.activeFilterCount == 0) return const SizedBox.shrink();

    final years = switch ((q.yearFrom, q.yearTo)) {
      (final int a, final int b) => '$a – $b',
      (final int a, null) => 'From $a',
      (null, final int b) => 'Until $b',
      _ => null,
    };

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final id in q.genreIds)
            _chip(
              c.genreName(id),
              () => c.applyQuery(
                q.copyWith(genreIds: {...q.genreIds}..remove(id)),
              ),
            ),
          if (years != null)
            _chip(
              years,
              () => c.applyQuery(
                q.copyWith(yearFrom: () => null, yearTo: () => null),
              ),
            ),
          if (q.minRating != null)
            _chip(
              '★ ${q.minRating!.toStringAsFixed(1)}+',
              () => c.applyQuery(q.copyWith(minRating: () => null)),
            ),
          if (q.language != null)
            _chip(
              Languages.nameOf(q.language!),
              () => c.applyQuery(q.copyWith(language: () => null)),
            ),
          TextButton(onPressed: c.clearFilters, child: const Text('Clear all')),
        ],
      ),
    );
  }

  Widget _chip(String label, VoidCallback onDeleted) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: InputChip(
      label: Text(label),
      onDeleted: onDeleted,
      deleteButtonTooltipMessage: 'Remove filter',
    ),
  );
}

/// List row with poster, metadata and edit/delete actions.
class DiscoveryMovieTile extends StatelessWidget {
  const DiscoveryMovieTile({
    super.key,
    required this.movie,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Movie movie;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final meta = [
      ?movie.releaseYear,
      ?MovieFormatters.runtime(movie.runtime),
      if (movie.originalLanguage != null)
        Languages.nameOf(movie.originalLanguage!),
    ].join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 0, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 64,
                  height: 96,
                  child: MoviePosterImage(url: movie.posterUrl, iconSize: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(meta, style: muted),
                    ],
                    if (movie.genres.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        movie.genres.join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: muted,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: MovieCard.starColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          movie.voteAverage > 0
                              ? movie.voteAverage.toStringAsFixed(1)
                              : '–',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Movie actions',
                onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
