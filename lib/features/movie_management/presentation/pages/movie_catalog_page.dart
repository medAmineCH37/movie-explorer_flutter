import 'package:flutter/material.dart';

import '../../data/models/movie_category.dart';
import '../../data/repositories/supabase_movies_repository.dart';
import '../../domain/repositories/movies_repository.dart';
import '../controllers/movie_catalog_controller.dart';
import '../movie_actions.dart';
import '../widgets/movie_card.dart';
import '../widgets/movie_state_views.dart';

/// Browsable catalogue: one tab per list, infinite scrolling grid, and an
/// "Add movie" button.
class MovieCatalogPage extends StatefulWidget {
  const MovieCatalogPage({
    super.key,
    this.initialCategory = MovieCategory.popular,
    this.repository,
  });

  final MovieCategory initialCategory;
  final MoviesRepository? repository;

  @override
  State<MovieCatalogPage> createState() => _MovieCatalogPageState();
}

class _MovieCatalogPageState extends State<MovieCatalogPage> {
  late final MoviesRepository _repository;
  late final Map<MovieCategory, MovieCatalogController> _controllers;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupabaseMoviesRepository();
    _controllers = {
      for (final category in MovieCategory.values)
        category: MovieCatalogController(
          category: category,
          repository: _repository,
        ),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: MovieCategory.values.length,
      initialIndex: widget.initialCategory.index,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Movie catalogue',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final category in MovieCategory.values)
                Tab(icon: Icon(category.icon), text: category.label),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => MovieActions.openEditor(context, _repository),
          icon: const Icon(Icons.add),
          label: const Text('Add movie'),
        ),
        body: TabBarView(
          children: [
            for (final category in MovieCategory.values)
              _CategoryGrid(controller: _controllers[category]!),
          ],
        ),
      ),
    );
  }
}

class _CategoryGrid extends StatefulWidget {
  const _CategoryGrid({required this.controller});

  final MovieCatalogController controller;

  @override
  State<_CategoryGrid> createState() => _CategoryGridState();
}

class _CategoryGridState extends State<_CategoryGrid>
    with AutomaticKeepAliveClientMixin {
  MovieCatalogController get _controller => widget.controller;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (!_controller.hasLoaded) _controller.loadInitial();
  }

  bool _onScroll(ScrollNotification notification) {
    // After a failed page, wait for the explicit retry button.
    if (notification.metrics.extentAfter < 600 &&
        _controller.loadMoreError == null) {
      _controller.loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.isLoading && _controller.movies.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_controller.error != null && _controller.movies.isEmpty) {
          return Center(
            child: MovieLoadError(
              message: _controller.error!,
              onRetry: _controller.loadInitial,
            ),
          );
        }

        if (_controller.movies.isEmpty) {
          return RefreshIndicator(
            onRefresh: _controller.loadInitial,
            child: ListView(
              children: const [
                SizedBox(height: 120),
                MovieEmptyState(message: 'No movies in this list yet.'),
              ],
            ),
          );
        }

        return NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: RefreshIndicator(
            onRefresh: _controller.loadInitial,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          childAspectRatio: 0.52,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 18,
                        ),
                    itemCount: _controller.movies.length,
                    itemBuilder: (context, index) =>
                        MovieCard(movie: _controller.movies[index]),
                  ),
                ),
                SliverToBoxAdapter(child: _Footer(controller: _controller)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.controller});

  final MovieCatalogController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (controller.loadMoreError != null) {
      return MovieLoadError(
        message: controller.loadMoreError!,
        onRetry: controller.loadMore,
      );
    }
    if (!controller.hasMore) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text("You've reached the end of this list.")),
      );
    }
    return const SizedBox(height: 48);
  }
}
