import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../movie_management/data/models/movie.dart';
import '../controllers/collection_controller.dart';
import '../widgets/collection_empty_state.dart';
import '../widgets/collection_movie_card.dart';
import '../widgets/collection_tabs.dart';
import '../../../user_management/data/auth_service.dart';

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  late final CollectionController _controller;
  final AuthService _authService = AuthService();

  late final StreamSubscription<AuthState> _authSubscription;

  bool get _isAuthenticated => _authService.currentUser != null;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();

    _controller = CollectionController();

    if (_isAuthenticated) {
      _controller.loadFavorites();
    }

    _authSubscription = _authService.authStateChanges.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        if (!mounted) return;

        setState(() {
          // Rebuild the page to remove the sign-in screen.
        });

        if (_selectedIndex == 0) {
          _controller.loadFavorites();
        } else {
          _controller.loadWatchlist();
        }
      } else if (data.event == AuthChangeEvent.signedOut) {
        if (!mounted) return;

        setState(() {
          _selectedIndex = 0;
          _controller.favorites = [];
          _controller.watchlist = [];
          _controller.favoritesError = null;
          _controller.watchlistError = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    setState(() => _selectedIndex = index);

    if (index == 0) {
      if (_controller.favorites.isEmpty && !_controller.isFavoritesLoading) {
        _controller.loadFavorites();
      }
    } else {
      if (_controller.watchlist.isEmpty && !_controller.isWatchlistLoading) {
        _controller.loadWatchlist();
      }
    }
  }

  Future<void> _openMovieDetails(int movieId) async {
    await context.push('/movie/$movieId');

    if (!mounted) return;

    if (_selectedIndex == 0) {
      await _controller.loadFavorites();
    } else {
      await _controller.loadWatchlist();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFavorites = _selectedIndex == 0;
    if (!_isAuthenticated) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Collection'),
          leading: IconButton(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 64),
                const SizedBox(height: 20),
                Text(
                  'Sign in to access your collection',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your Favorites and Watchlist are saved to your account.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.push(
                    '/login?redirect=${Uri.encodeComponent('/collection')}',
                  ),
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ),
        ),
      );
    }
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
          final movies = isFavorites
              ? _controller.favorites
              : _controller.watchlist;
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
        title: isFavorites ? 'No favorites yet' : 'Your watchlist is empty',
        description: isFavorites
            ? 'Add movies you love to keep them all in one place.'
            : 'Save movies you want to watch later.',
        icon: isFavorites ? Icons.favorite_border : Icons.bookmark_border,
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
          onTap: () => _openMovieDetails(movie.id),
        );
      },
    );
  }
}
