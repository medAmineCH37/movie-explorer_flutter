import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/collection_repository_impl.dart';
import '../../../user_management/data/auth_service.dart';

class MovieCollectionActions extends StatefulWidget {
  const MovieCollectionActions({super.key, required this.movieId});

  final int movieId;

  @override
  State<MovieCollectionActions> createState() => _MovieCollectionActionsState();
}

class _MovieCollectionActionsState extends State<MovieCollectionActions> {
  late final CollectionRepositoryImpl _repository;
  final AuthService _authService = AuthService();
  late final StreamSubscription<AuthState> _authSubscription;

  bool get _isAuthenticated => _authService.currentUser != null;

  bool _isFavorite = false;
  bool _isInWatchlist = false;

  bool _isLoadingStatus = true;
  bool _isUpdatingFavorite = false;
  bool _isUpdatingWatchlist = false;

  @override
  void initState() {
    super.initState();

    _repository = CollectionRepositoryImpl();
    _loadStatus();

    _authSubscription = _authService.authStateChanges.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        setState(() {
          _isLoadingStatus = true;
        });
        _loadStatus();
      } else if (data.event == AuthChangeEvent.signedOut) {
        setState(() {
          _isFavorite = false;
          _isInWatchlist = false;
          _isLoadingStatus = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    if (!_isAuthenticated) {
      if (!mounted) return;

      setState(() {
        _isLoadingStatus = false;
      });
      return;
    }

    try {
      final results = await Future.wait([
        _repository.isFavorite(widget.movieId),
        _repository.isInWatchlist(widget.movieId),
      ]);

      if (!mounted) return;

      setState(() {
        _isFavorite = results[0];
        _isInWatchlist = results[1];
        _isLoadingStatus = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoadingStatus = false;
      });

      _showMessage('Could not load collection status: $error');
    }
  }

  Future<void> _toggleFavorite() async {
    setState(() => _isUpdatingFavorite = true);

    try {
      if (_isFavorite) {
        await _repository.removeFavorite(widget.movieId);
      } else {
        await _repository.addFavorite(widget.movieId);
      }

      if (!mounted) return;

      setState(() => _isFavorite = !_isFavorite);

      _showMessage(
        _isFavorite ? 'Added to Favorites' : 'Removed from Favorites',
      );
    } catch (error) {
      if (mounted) {
        _showMessage('Could not update Favorites: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingFavorite = false);
      }
    }
  }

  Future<void> _toggleWatchlist() async {
    setState(() => _isUpdatingWatchlist = true);

    try {
      if (_isInWatchlist) {
        await _repository.removeFromWatchlist(widget.movieId);
      } else {
        await _repository.addToWatchlist(widget.movieId);
      }

      if (!mounted) return;

      setState(() => _isInWatchlist = !_isInWatchlist);

      _showMessage(
        _isInWatchlist ? 'Added to Watchlist' : 'Removed from Watchlist',
      );
    } catch (error) {
      if (mounted) {
        _showMessage('Could not update Watchlist: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingWatchlist = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _requestLogin() {
    context.push(
      '/login?redirect=${Uri.encodeComponent('/movie/${widget.movieId}')}',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingStatus) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isAuthenticated) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Sign in to save movies to your collection.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _requestLogin, child: const Text('Sign in')),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: _isUpdatingFavorite ? null : _toggleFavorite,
          icon: _isUpdatingFavorite
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
          label: Text(
            _isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _isUpdatingWatchlist ? null : _toggleWatchlist,
          icon: _isUpdatingWatchlist
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(_isInWatchlist ? Icons.bookmark : Icons.bookmark_border),
          label: Text(
            _isInWatchlist ? 'Remove from Watchlist' : 'Add to Watchlist',
          ),
        ),
      ],
    );
  }
}
