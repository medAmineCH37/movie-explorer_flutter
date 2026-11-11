import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../personal_collection/presentation/widgets/movie_collection_actions.dart';
import '../../../ratings_reviews/presentation/widgets/movie_reviews_section.dart';
import '../../data/models/movie_details.dart';
import '../../data/services/tmdb_service.dart';
import '../movie_formatters.dart';
import '../widgets/movie_card.dart';
import '../widgets/movie_poster_image.dart';

class MovieDetailsPage extends StatefulWidget {
  const MovieDetailsPage({super.key, required this.movieId, this.tmdbService});

  final int movieId;
  final TmdbService? tmdbService;

  @override
  State<MovieDetailsPage> createState() => _MovieDetailsPageState();
}

class _MovieDetailsPageState extends State<MovieDetailsPage> {
  late final TmdbService _tmdbService;
  late Future<MovieDetails> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _tmdbService = widget.tmdbService ?? TmdbService();
    _detailsFuture = _tmdbService.getFullMovieDetails(widget.movieId);
  }

  @override
  void dispose() {
    if (widget.tmdbService == null) _tmdbService.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _detailsFuture = _tmdbService.getFullMovieDetails(widget.movieId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<MovieDetails>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final details = snapshot.data;
          if (snapshot.hasError || details == null) {
            final error = snapshot.error;
            return _ErrorView(
              notFound: error is TmdbException && error.isNotFound,
              onRetry: _retry,
            );
          }

          return _DetailsView(details: details);
        },
      ),
    );
  }
}

class _DetailsView extends StatelessWidget {
  const _DetailsView({required this.details});

  final MovieDetails details;

  @override
  Widget build(BuildContext context) {
    final movie = details.movie;
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          backgroundColor: const Color(0xFF101014),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                MoviePosterImage(url: movie.backdropUrl ?? movie.posterUrl),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x66101014), Color(0xFF101014)],
                      stops: [0.35, 1],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          sliver: SliverList.list(
            children: [
              _Header(details: details),
              const SizedBox(height: 20),
              _SourceRating(
                score: movie.voteAverage,
                voteCount: movie.voteCount,
              ),
              if (details.trailer != null) ...[
                const SizedBox(height: 16),
                _TrailerButton(trailer: details.trailer!),
              ],
              if (movie.genres.isNotEmpty) ...[
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final genre in movie.genres)
                      Chip(
                        label: Text(genre),
                        backgroundColor: const Color(0xFF292433),
                      ),
                  ],
                ),
              ],
              const _SectionTitle('Overview'),
              Text(
                movie.overview.isNotEmpty
                    ? movie.overview
                    : 'No overview available for this movie.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                  color: Colors.white70,
                ),
              ),
              if (details.directors.isNotEmpty) ...[
                const _SectionTitle('Directed by'),
                Text(
                  details.directors.join(', '),
                  style: theme.textTheme.titleMedium,
                ),
              ],
              if (details.cast.isNotEmpty) ...[
                const _SectionTitle('Cast'),
                _CastRow(cast: details.cast),
              ],
              const _SectionTitle('Details'),
              _Facts(details: details),
              const _SectionTitle('My Collection'),
              MovieCollectionActions(movieId: movie.id),
              const _SectionTitle('Ratings & reviews'),
              MovieReviewsSection(movie: movie),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 12),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.details});

  final MovieDetails details;

  @override
  Widget build(BuildContext context) {
    final movie = details.movie;
    final theme = Theme.of(context);
    final meta = [
      ?movie.releaseYear,
      ?MovieFormatters.runtime(movie.runtime),
      ?(details.languageName ?? movie.originalLanguage?.toUpperCase()),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 115,
          height: 170,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
          ),
          clipBehavior: Clip.antiAlias,
          child: MoviePosterImage(url: movie.posterUrl, iconSize: 40),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                movie.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (details.tagline.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  details.tagline,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  meta.join('  •  '),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// TMDB score, labelled with its source so it is not confused with the
/// community rating.
class _SourceRating extends StatelessWidget {
  const _SourceRating({required this.score, required this.voteCount});

  final double score;
  final int voteCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasScore = voteCount > 0 && score > 0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(
              Icons.star_rounded,
              color: MovieCard.starColor,
              size: 30,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: hasScore ? score.toStringAsFixed(1) : '–',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (hasScore)
                          TextSpan(
                            text: ' / 10',
                            style: theme.textTheme.bodyMedium,
                          ),
                      ],
                    ),
                  ),
                  Text(
                    hasScore
                        ? 'TMDB rating · '
                              '${MovieFormatters.compactCount(voteCount)} votes'
                        : 'No TMDB rating yet',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrailerButton extends StatelessWidget {
  const _TrailerButton({required this.trailer});

  final MovieVideo trailer;

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(
        trailer.watchUrl,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not open the trailer.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => _open(context),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      icon: const Icon(Icons.play_circle_outline),
      label: Text(trailer.type == 'Teaser' ? 'Watch teaser' : 'Watch trailer'),
    );
  }
}

class _CastRow extends StatelessWidget {
  const _CastRow({required this.cast});

  final List<CastMember> cast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cast.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final member = cast[index];
          final initial = member.name.isEmpty ? '?' : member.name[0];
          return SizedBox(
            width: 84,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  foregroundImage: member.profileUrl == null
                      ? null
                      : CachedNetworkImageProvider(member.profileUrl!),
                  child: Text(
                    initial.toUpperCase(),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  member.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (member.character.isNotEmpty)
                  Text(
                    member.character,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.details});

  final MovieDetails details;

  @override
  Widget build(BuildContext context) {
    final movie = details.movie;
    final runtime = MovieFormatters.runtime(movie.runtime);
    final language =
        details.languageName ?? movie.originalLanguage?.toUpperCase();
    final facts = <(String, String)>[
      if (movie.releaseDate.isNotEmpty)
        ('Release date', MovieFormatters.date(movie.releaseDate)),
      if (runtime != null) ('Runtime', runtime),
      if (language != null) ('Original language', language),
      if (details.status.isNotEmpty) ('Status', details.status),
    ];
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            for (final (label, value) in facts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      value,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.notFound, required this.onRetry});

  final bool notFound;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      notFound ? Icons.movie_outlined : Icons.cloud_off,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      notFound
                          ? 'This movie is no longer in the catalogue.'
                          : 'Could not load movie details.',
                      textAlign: TextAlign.center,
                    ),
                    if (!notFound) ...[
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
