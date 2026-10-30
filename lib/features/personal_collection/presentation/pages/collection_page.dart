
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../movie_management/data/models/movie.dart';
import '../controllers/collection_controller.dart';
import '../widgets/collection_empty_state.dart';
import '../widgets/collection_movie_card.dart';
import '../widgets/collection_tabs.dart';

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  late final CollectionController _controller;

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = CollectionController();
    _controller.loadFavorites();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    setState(() => _selectedIndex = index);

    if (index == 0) {
      if (_controller.favorites.isEmpty &&
          !_controller.isFavoritesLoading) {
        _controller.loadFavorites();
      }
    } else {
      if (_controller.watchlist.isEmpty &&
          !_controller.isWatchlistLoading) {
        _controller.loadWatchlist();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFavorites = _selectedIndex == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Collection'),
        leading: IconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to home',
        ),
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final movies =
              isFavorites ? _controller.favorites : _controller.watchlist;
          final isLoading = isFavorites
              ? _controller.isFavoritesLoading
              : _controller.isWatchlistLoading;
          final error = isFavorites
              ? _controller.favoritesError
              : _controller.watchlistError;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: CollectionTabs(
                  selectedIndex: _selectedIndex,
                  onChanged: _onTabChanged,
                ),
              ),
              Expanded(
                child: _buildContent(
                  movies: movies,
                  isLoading: isLoading,
                  error: error,
                  isFavorites: isFavorites,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent({
    required List<Movie> movies,
    required bool isLoading,
    required String? error,
    required bool isFavorites,
  }) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return CollectionEmptyState(
        title: 'Something went wrong',
        description: error,
        icon: Icons.error_outline,
        buttonLabel: 'Try again',
        onAction: () => isFavorites
            ? _controller.loadFavorites()
            : _controller.loadWatchlist(),
      );
    }

    if (movies.isEmpty) {
      return CollectionEmptyState(
        title: isFavorites
            ? 'No favorites yet'
            : 'Your watchlist is empty',
        description: isFavorites
            ? 'Add movies you love to keep them all in one place.'
            : 'Save movies you want to watch later.',
        icon: isFavorites
            ? Icons.favorite_border
            : Icons.bookmark_border,
        buttonLabel: 'Discover movies',
        onAction: () => context.push('/search'),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 20,
        childAspectRatio: 0.54,
      ),
      itemCount: movies.length,
      itemBuilder: (context, index) {
        final movie = movies[index];

        return CollectionMovieCard(
          movie: movie,
          onRemove: () => isFavorites
              ? _controller.removeFavorite(movie.id)
              : _controller.removeFromWatchlist(movie.id),
          onTap: () => context.push('/movie/${movie.id}'),
        );
      },
    );
  }
}
