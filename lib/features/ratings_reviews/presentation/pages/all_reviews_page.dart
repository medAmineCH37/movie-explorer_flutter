import 'package:flutter/material.dart';

import '../../../movie_management/data/models/movie.dart';
import '../../../movie_management/data/repositories/supabase_movies_repository.dart';
import '../../../movie_management/domain/repositories/movies_repository.dart';
import '../../../movie_management/presentation/widgets/movie_poster_image.dart';
import '../../domain/models/review_sort.dart';
import '../../domain/repositories/reviews_repository.dart';
import '../controllers/all_reviews_controller.dart';
import '../widgets/ai_review_summary_card.dart';
import '../widgets/rating_summary_card.dart';
import '../widgets/review_actions.dart';
import '../../../../core/navigation/app_shell.dart';

/// Every review of a movie, sortable, 10 per page.
class AllReviewsPage extends StatefulWidget {
  const AllReviewsPage({
    super.key,
    required this.movieId,
    this.movie,
    this.repository,
    this.moviesRepository,
  });

  final int movieId;

  /// Movie already loaded by the caller (route `extra`); fetched otherwise.
  final Movie? movie;
  final ReviewsRepository? repository;
  final MoviesRepository? moviesRepository;

  @override
  State<AllReviewsPage> createState() => _AllReviewsPageState();
}

class _AllReviewsPageState extends State<AllReviewsPage> {
  late final AllReviewsController _controller;
  final ScrollController _scroll = ScrollController();
  Movie? _movie;

  @override
  void initState() {
    super.initState();
    _controller = AllReviewsController(
      movieId: widget.movieId,
      repository: widget.repository,
    )..load();
    _loadMovie();
  }

  Future<void> _loadMovie() async {
    if (widget.movie != null) {
      _movie = widget.movie;
      return;
    }
    try {
      final movies = widget.moviesRepository ?? SupabaseMoviesRepository();
      final found = await movies.getMoviesByIds([widget.movieId]);
      if (mounted) setState(() => _movie = found[widget.movieId]);
    } catch (_) {
      // The reviews stay usable without movie metadata.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _goToPage(int page) async {
    await _controller.goToPage(page);
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const ShellLeading(),
        leadingWidth: shellLeadingWidth(context),
        title: const Text('Reviews'),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final c = _controller;
          final theme = Theme.of(context);
          final page = c.page;
          final actions = ReviewCardActions(
            repository: c.repository,
            movieTitle: _movie?.title ?? 'This movie',
            movieYear: _movie?.releaseYear,
            isSignedIn: c.isSignedIn,
            isAdmin: c.isAdmin,
            myScore: c.summary.myScore,
            toggleLike: c.toggleLike,
            deleteReview: c.deleteReview,
            report: c.report,
            onChanged: c.reload,
          );

          return RefreshIndicator(
            onRefresh: c.reload,
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _MovieHeader(movie: _movie, reviewCount: c.summary.reviewCount),
                const SizedBox(height: 16),
                RatingSummaryCard(summary: c.summary),
                const SizedBox(height: 12),
                AiReviewSummaryCard(
                  repository: c.repository,
                  movieId: widget.movieId,
                  reviewCount: c.summary.reviewCount,
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final sort in ReviewSort.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(sort.label),
                            selected: c.sort == sort,
                            onSelected: c.isLoading
                                ? null
                                : (_) => c.changeSort(sort),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (c.isLoading)
                  const LinearProgressIndicator(minHeight: 2)
                else
                  const SizedBox(height: 2),
                if (c.error != null) ...[
                  const SizedBox(height: 24),
                  Text(c.error!, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: c.reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ),
                ] else if (page != null && page.reviews.isEmpty) ...[
                  const SizedBox(height: 40),
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 40,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No reviews yet. Be the first to share yours from the '
                    'movie page!',
                    textAlign: TextAlign.center,
                  ),
                ],
                for (final review in c.reviews) ...[
                  const SizedBox(height: 12),
                  actions.card(context, review),
                ],
                if (page != null && page.totalPages > 1) ...[
                  const SizedBox(height: 16),
                  _Pager(page: page, enabled: !c.isLoading, onPage: _goToPage),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MovieHeader extends StatelessWidget {
  const _MovieHeader({required this.movie, required this.reviewCount});

  final Movie? movie;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = [
      ?movie?.releaseYear,
      reviewCount == 1 ? '1 review' : '$reviewCount reviews',
    ].join(' · ');

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 60,
            height: 90,
            child: MoviePosterImage(url: movie?.posterUrl, iconSize: 24),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                movie?.title ?? 'Reviews',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.enabled,
    required this.onPage,
  });

  final ReviewPage page;
  final bool enabled;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Previous page',
          onPressed: enabled && page.hasPrevious
              ? () => onPage(page.page - 1)
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            'Page ${page.page} of ${page.totalPages}',
            textAlign: TextAlign.center,
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Next page',
          onPressed: enabled && page.hasNext
              ? () => onPage(page.page + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
