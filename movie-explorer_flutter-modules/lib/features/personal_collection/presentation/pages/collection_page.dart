import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../movie_management/data/models/movie.dart';
import '../../../user_management/data/auth_service.dart';
import '../../domain/models/collection_entry.dart';
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
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  late final StreamSubscription<AuthState> _authSubscription;

  bool get _isAuthenticated => _authService.currentUser != null;
  int _selectedIndex = 0;
  String _query = '';
  String? _genre;
  String? _year;
  String _sort = 'Title';

  @override
  void initState() {
    super.initState();
    _controller = CollectionController();
    if (_isAuthenticated) _loadAll();
    _authSubscription = _authService.authStateChanges.listen((data) {
      if (!mounted) return;
      if (data.event == AuthChangeEvent.signedIn) {
        setState(() {});
        _loadAll();
      } else if (data.event == AuthChangeEvent.signedOut) {
        setState(() {
          _selectedIndex = 0;
          _controller.favorites = [];
          _controller.watchlist = [];
          _controller.watched = [];
          _controller.watchlistPriorities.clear();
          _controller.watchedDates.clear();
        });
      }
    });
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _controller.loadFavorites(),
      _controller.loadWatchlist(),
      _controller.loadWatched(),
    ]);
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  List<Movie> get _currentMovies => switch (_selectedIndex) {
    0 => _controller.favorites,
    1 => _controller.watchlist,
    _ => _controller.watched,
  };

  List<Movie> get _visibleMovies {
    final movies = _currentMovies.where((movie) {
      final matchesQuery =
          _query.isEmpty ||
          movie.title.toLowerCase().contains(_query) ||
          movie.overview.toLowerCase().contains(_query) ||
          movie.genres.any((genre) => genre.toLowerCase().contains(_query));
      final matchesGenre = _genre == null || movie.genres.contains(_genre);
      final movieYear = movie.releaseDate.length >= 4
          ? movie.releaseDate.substring(0, 4)
          : null;
      return matchesQuery &&
          matchesGenre &&
          (_year == null || movieYear == _year);
    }).toList();

    movies.sort((a, b) {
      switch (_sort) {
        case 'Release year':
          return b.releaseDate.compareTo(a.releaseDate);
        case 'TMDB score':
          return b.voteAverage.compareTo(a.voteAverage);
        case 'Priority':
          final rank = {
            WatchPriority.high: 0,
            WatchPriority.medium: 1,
            WatchPriority.low: 2,
          };
          return (rank[_controller.watchlistPriorities[a.id]] ?? 1).compareTo(
            rank[_controller.watchlistPriorities[b.id]] ?? 1,
          );
        default:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
    });
    return movies;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) return _signInPage();

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
          final movies = _visibleMovies;
          final isLoading = switch (_selectedIndex) {
            0 => _controller.isFavoritesLoading,
            1 => _controller.isWatchlistLoading,
            _ => _controller.isWatchedLoading,
          };
          final error = switch (_selectedIndex) {
            0 => _controller.favoritesError,
            1 => _controller.watchlistError,
            _ => _controller.watchedError,
          };
          return Column(
            children: [
              _dashboard(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: CollectionTabs(
                  selectedIndex: _selectedIndex,
                  onChanged: (index) => setState(() {
                    _selectedIndex = index;
                    _genre = null;
                    _year = null;
                  }),
                ),
              ),
              _searchAndFilters(),
              Expanded(child: _buildContent(movies, isLoading, error)),
            ],
          );
        },
      ),
    );
  }

  Widget _dashboard() {
    final all = <int, Movie>{
      for (final movie in [
        ..._controller.favorites,
        ..._controller.watchlist,
        ..._controller.watched,
      ])
        movie.id: movie,
    }.values.toList();
    final watchedRuntime = _controller.watched.fold<int>(
      0,
      (sum, movie) => sum + (movie.runtime ?? 0),
    );
    final genreCounts = <String, int>{};
    for (final movie in all) {
      for (final genre in movie.genres) {
        genreCounts.update(genre, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    final topGenre = genreCounts.isEmpty
        ? 'Add movies to see genre trends'
        : genreCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your library at a glance',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statCard('Movies', '${all.length}', Icons.movie_outlined),
              _statCard(
                'Watched',
                '${_controller.watched.length}',
                Icons.visibility_outlined,
              ),
              _statCard(
                'Viewing time',
                _formatRuntime(watchedRuntime),
                Icons.schedule,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Favorites ${_controller.favorites.length}  ·  Watchlist ${_controller.watchlist.length}  ·  Watched ${_controller.watched.length}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Top genre: $topGenre',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon) => Expanded(
    child: Card(
      margin: const EdgeInsets.only(right: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18),
            const SizedBox(height: 5),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              maxLines: 1,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    ),
  );

  String _formatRuntime(int minutes) =>
      minutes == 0 ? '—' : '${minutes ~/ 60}h ${minutes % 60}m';

  Widget _searchAndFilters() {
    final movies = _currentMovies;
    final genres = movies.expand((movie) => movie.genres).toSet().toList()
      ..sort();
    final years =
        movies
            .map(
              (movie) => movie.releaseDate.length >= 4
                  ? movie.releaseDate.substring(0, 4)
                  : '',
            )
            .where((year) => year.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search your collection',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.clear),
                    ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _dropdown<String?>(
                  value: _genre,
                  label: 'Genre',
                  items: [null, ...genres],
                  itemLabel: (value) => value ?? 'All genres',
                  onChanged: (value) => setState(() => _genre = value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _dropdown<String?>(
                  value: _year,
                  label: 'Year',
                  items: [null, ...years],
                  itemLabel: (value) => value ?? 'All years',
                  onChanged: (value) => setState(() => _year = value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _dropdown<String>(
                  value: _sort,
                  label: 'Sort',
                  items: const [
                    'Title',
                    'Release year',
                    'TMDB score',
                    'Priority',
                  ],
                  itemLabel: (value) => value,
                  onChanged: (value) =>
                      setState(() => _sort = value ?? 'Title'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required T value,
    required String label,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) => DropdownButtonFormField<T>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
    ),
    items: items
        .map(
          (item) => DropdownMenuItem(
            value: item,
            child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: onChanged,
  );

  Widget _buildContent(List<Movie> movies, bool isLoading, String? error) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return CollectionEmptyState(
        title: 'Something went wrong',
        description: error,
        icon: Icons.error_outline,
        buttonLabel: 'Try again',
        onAction: () => switch (_selectedIndex) {
          0 => _controller.loadFavorites(),
          1 => _controller.loadWatchlist(),
          _ => _controller.loadWatched(),
        },
      );
    }
    if (movies.isEmpty) {
      final empty = _query.isNotEmpty || _genre != null || _year != null;
      return CollectionEmptyState(
        title: empty
            ? 'No matching movies'
            : switch (_selectedIndex) {
                0 => 'No favorites yet',
                1 => 'Your watchlist is empty',
                _ => 'No watched movies yet',
              },
        description: empty
            ? 'Try changing your search or filters.'
            : switch (_selectedIndex) {
                0 => 'Add movies you love to keep them all in one place.',
                1 => 'Save movies you want to watch later.',
                _ => 'Mark a movie as watched to start your viewing history.',
              },
        icon: empty
            ? Icons.search_off
            : switch (_selectedIndex) {
                0 => Icons.favorite_border,
                1 => Icons.bookmark_border,
                _ => Icons.visibility_outlined,
              },
        buttonLabel: 'Discover movies',
        onAction: () => context.push('/search'),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 18,
        childAspectRatio: 0.42,
      ),
      itemCount: movies.length,
      itemBuilder: (context, index) {
        final movie = movies[index];
        final watchedAt = _controller.watchedDates[movie.id];
        return CollectionMovieCard(
          movie: movie,
          onRemove: () => switch (_selectedIndex) {
            0 => _controller.removeFavorite(movie.id),
            1 => _controller.removeFromWatchlist(movie.id),
            _ => _controller.removeWatched(movie.id),
          },
          onTap: () async {
            await context.push('/movie/${movie.id}');
            if (mounted) _loadAll();
          },
          subtitle: _selectedIndex == 2 && watchedAt != null
              ? 'Watched ${MaterialLocalizations.of(context).formatMediumDate(watchedAt)}'
              : _selectedIndex == 1
              ? '${_controller.watchlistPriorities[movie.id]?.label ?? 'Medium'} priority'
              : movie.genres.take(2).join(' · '),
          action: switch (_selectedIndex) {
            0 => _markWatchedAction(movie.id),
            1 => _watchlistActions(movie),
            _ => _moveToWatchlistAction(movie.id),
          },
        );
      },
    );
  }

  Widget _watchlistActions(Movie movie) => Row(
    children: [
      Expanded(
        child: DropdownButton<WatchPriority>(
          isExpanded: true,
          value:
              _controller.watchlistPriorities[movie.id] ?? WatchPriority.medium,
          items: WatchPriority.values
              .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
              .toList(),
          onChanged: (priority) {
            if (priority != null) {
              _controller.updatePriority(movie.id, priority);
            }
          },
        ),
      ),
      _markWatchedAction(movie.id),
    ],
  );

  Widget _markWatchedAction(int movieId) => IconButton(
    tooltip: 'Mark watched',
    icon: const Icon(Icons.visibility_outlined),
    onPressed: () => _chooseWatchedDate(movieId),
  );

  Widget _moveToWatchlistAction(int movieId) => TextButton.icon(
    onPressed: () => _controller.addToWatchlist(movieId),
    icon: const Icon(Icons.bookmark_add_outlined, size: 18),
    label: const Text('Move to Watchlist'),
  );

  Future<void> _chooseWatchedDate(int movieId) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'When did you watch this movie?',
    );
    if (date != null) await _controller.markWatched(movieId, date);
  }

  Widget _signInPage() => Scaffold(
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
              'Your Favorites, Watchlist and Watched movies are saved to your account.',
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
