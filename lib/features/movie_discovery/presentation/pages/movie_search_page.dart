
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../movie_management/data/models/movie.dart';
import '../../../movie_management/data/services/tmdb_service.dart';

class MovieSearchPage extends StatefulWidget {
  const MovieSearchPage({super.key});

  @override
  State<MovieSearchPage> createState() => _MovieSearchPageState();
}

class _MovieSearchPageState extends State<MovieSearchPage> {
  final TmdbService _tmdbService = TmdbService();
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;
  List<Movie> _movies = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasSearched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _tmdbService.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _movies = [];
        _isLoading = false;
        _errorMessage = null;
        _hasSearched = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _searchMovies(query);
    });
  }

  Future<void> _searchMovies(String query) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasSearched = true;
    });

    try {
      final results = await _tmdbService.searchMovies(query);

      if (!mounted) return;

      setState(() {
        _movies = results;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _movies = [];
        _isLoading = false;
        _errorMessage = 'Could not search movies. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Movies'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search movies by title...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
            ),
            Expanded(
              child: _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _searchMovies(_searchController.text),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasSearched) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 56),
            SizedBox(height: 12),
            Text('Search for your next favorite movie'),
          ],
        ),
      );
    }

    if (_movies.isEmpty) {
      return const Center(
        child: Text('No movies found. Try another title.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _movies.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final movie = _movies[index];

        return Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.all(10),
            leading: SizedBox(
              width: 64,
              height: 96,
              child: movie.posterUrl == null
                  ? const Icon(Icons.movie_outlined, size: 36)
                  : CachedNetworkImage(
                      imageUrl: movie.posterUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) =>
                          const Icon(Icons.movie_outlined, size: 36),
                    ),
            ),
            title: Text(
              movie.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (movie.releaseDate.isNotEmpty)
                    Text(movie.releaseDate.split('-').first),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFFC857),
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(movie.voteAverage.toStringAsFixed(1)),
                    ],
                  ),
                ],
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/movie/${movie.id}'),
          ),
        );
      },
    );
  }
}
