import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/movie_management/data/models/movie.dart';
import '../features/movie_management/data/services/tmdb_service.dart';
import '../features/user_management/presentation/providers/auth_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TmdbService _tmdbService = TmdbService();
  late Future<List<Movie>> _moviesFuture;

  static const List<_ModuleItem> _allModules = [
    _ModuleItem(
      id: 'user-management',
      title: 'User Management',
      description: 'Accounts, authentication and profiles',
      icon: Icons.person_outline,
      adminOnly: true, // Restricted to administrators
    ),
    _ModuleItem(
      id: 'movie-management',
      title: 'Movie Management',
      description: 'Explore movie details and metadata',
      icon: Icons.movie_outlined,
    ),
    _ModuleItem(
      id: 'ratings-reviews',
      title: 'Ratings & Reviews',
      description: 'Rate movies and share your opinions',
      icon: Icons.star_outline,
    ),
    _ModuleItem(
      id: 'personal-collection',
      title: 'My Collection',
      description: 'Manage favorites and your watchlist',
      icon: Icons.bookmark_border,
    ),
    _ModuleItem(
      id: 'movie-discovery',
      title: 'Movie Discovery',
      description: 'Search, filter and sort movies',
      icon: Icons.search,
    ),
    _ModuleItem(
      id: 'recommendations-custom-lists',
      title: 'Recommendations & Lists',
      description: 'Discover conversational AI suggestions with Gemini',
      icon: Icons.auto_awesome_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _moviesFuture = _tmdbService.getPopularMovies();
  }

  @override
  void dispose() {
    _tmdbService.dispose();
    super.dispose();
  }

  void _retryLoadingMovies() {
    setState(() {
      _moviesFuture = _tmdbService.getPopularMovies();
    });
  }

  Future<void> _handleAccountTap() async {
    final authState = ref.read(authProvider);
    final user = authState.user;

    if (user == null) {
      if (mounted) {
        context.push('/login');
      }
      return;
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFF5F3EE),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF1B1B19),
                    foregroundColor: Colors.white,
                    child: Icon(Icons.person),
                  ),
                  title: Text(
                    user.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text('${user.email} • Rôle: ${user.role.toUpperCase()}'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.account_box_outlined),
                  title: const Text('Mon Profil CINEA'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.push('/profile');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Color(0xFF96443C)),
                  title: const Text('Se déconnecter', style: TextStyle(color: Color(0xFF96443C), fontWeight: FontWeight.bold)),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await ref.read(authProvider.notifier).logout();
                    if (!mounted) return;
                    context.go('/login');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Déconnexion réussie.')),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final isAdmin = authState.user?.role.toLowerCase() == 'admin';

    // Filtrage dynamique des modules selon le rôle
    final visibleModules = _allModules.where((m) => !m.adminOnly || isAdmin).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie_filter_outlined),
            SizedBox(width: 10),
            Text('Movie Explorer', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search),
            tooltip: 'Search movies',
          ),
          IconButton(
            onPressed: _handleAccountTap,
            icon: Icon(
              authState.user != null ? Icons.account_circle : Icons.account_circle_outlined,
              color: authState.user != null ? const Color(0xFF8C692E) : null,
            ),
            tooltip: 'Account',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'YOUR NEXT MOVIE NIGHT',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Discover something unforgettable.',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<List<Movie>>(
              future: _moviesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _FeaturedLoading();
                }
                if (snapshot.hasError) {
                  return _LoadError(
                    message: 'Could not load movies from TMDB.',
                    onRetry: _retryLoadingMovies,
                  );
                }
                final movies = snapshot.data ?? [];
                if (movies.isEmpty) {
                  return const _EmptyMovies();
                }
                return _FeaturedMovie(movie: movies.first);
              },
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Popular Movies',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Icon(Icons.local_fire_department, color: colors.primary),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FutureBuilder<List<Movie>>(
              future: _moviesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 250,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return _LoadError(
                    message: 'Popular movies could not be loaded.',
                    onRetry: _retryLoadingMovies,
                  );
                }
                final movies = snapshot.data ?? [];
                if (movies.isEmpty) {
                  return const _EmptyMovies();
                }
                return SizedBox(
                  height: 250,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: movies.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      return _MoviePosterCard(movie: movies[index]);
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 36),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Explore the app',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
              child: Text(
                'Explore all the features of Movie Explorer.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
            ...visibleModules.map((module) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Card(
                  elevation: 1,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    leading: CircleAvatar(
                      backgroundColor: colors.primaryContainer,
                      foregroundColor: colors.onPrimaryContainer,
                      child: Icon(module.icon),
                    ),
                    title: Row(
                      children: [
                        Text(module.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (module.adminOnly) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8C692E),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('ADMIN', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ]
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(module.description),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      if (module.id == 'personal-collection') {
                        context.push('/collection');
                      } else if (module.id == 'recommendations-custom-lists') {
                        context.push('/ai-assistant');
                      } else {
                        context.push('/module/${module.id}');
                      }
                    },
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ModuleItem {
  const _ModuleItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.adminOnly = false,
  });
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool adminOnly;
}

class _FeaturedMovie extends StatelessWidget {
  const _FeaturedMovie({required this.movie});
  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final imageUrl = movie.backdropUrl ?? movie.posterUrl;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/movie/${movie.id}'),
          borderRadius: BorderRadius.circular(24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: 350,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null)
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => const _ImageFallback(),
                    )
                  else
                    const _ImageFallback(),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x55000000), Color(0xF0000000)],
                        stops: [0.15, 0.48, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 22,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'POPULAR RIGHT NOW',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          movie.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Color(0xFFFFC857), size: 20),
                            const SizedBox(width: 5),
                            Text(
                              movie.voteAverage.toStringAsFixed(1),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            if (movie.releaseDate.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Text(movie.releaseDate.split('-').first, style: const TextStyle(color: Colors.white70)),
                            ],
                          ],
                        ),
                        if (movie.overview.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            movie.overview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, height: 1.4),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoviePosterCard extends StatelessWidget {
  const _MoviePosterCard({required this.movie});
  final Movie movie;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: InkWell(
        onTap: () => context.push('/movie/${movie.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: double.infinity,
                  child: movie.posterUrl == null
                      ? const _ImageFallback()
                      : CachedNetworkImage(
                    imageUrl: movie.posterUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const _ImageFallback(loading: true),
                    errorWidget: (context, url, error) => const _ImageFallback(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              movie.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.star_rounded, color: Color(0xFFFFC857), size: 16),
                const SizedBox(width: 4),
                Text(movie.voteAverage.toStringAsFixed(1), style: Theme.of(context).textTheme.bodySmall),
                if (movie.releaseDate.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      movie.releaseDate.split('-').first,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedLoading extends StatelessWidget {
  const _FeaturedLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 350,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 36),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _EmptyMovies extends StatelessWidget {
  const _EmptyMovies();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: Text('No movies are available right now.')),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({this.loading = false});
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        loading ? Icons.image_outlined : Icons.movie_outlined,
        size: 36,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}