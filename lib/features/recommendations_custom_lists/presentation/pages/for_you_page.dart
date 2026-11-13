import '../../../../core/navigation/app_shell.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/custom_list.dart';
import '../controllers/for_you_controller.dart';
import '../widgets/hero_carousel.dart';
import '../widgets/movie_rail.dart';
import '../widgets/reco_ui.dart';

/// Module 6 home: streaming-style recommendations.
class ForYouPage extends StatefulWidget {
  const ForYouPage({super.key});

  @override
  State<ForYouPage> createState() => _ForYouPageState();
}

class _ForYouPageState extends State<ForYouPage> {
  final ForYouController _controller = ForYouController();
  late final StreamSubscription<AuthState> _auth;

  @override
  void initState() {
    super.initState();
    _controller.load();
    _auth = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.signedOut) {
        _controller.load();
      }
    });
  }

  @override
  void dispose() {
    _auth.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openLists() async {
    await context.push('/lists');
    if (mounted) unawaited(_controller.load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: shellMenuButton(context),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'For You',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Community lists',
            onPressed: () => context.push('/lists/community'),
            icon: const Icon(Icons.public),
          ),
          IconButton(
            tooltip: 'My lists',
            onPressed: _openLists,
            icon: const Icon(Icons.video_library_outlined),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final c = _controller;
          if (c.error != null && c.recommendations == null) {
            return ErrorRetry(message: c.error!, onRetry: c.load);
          }
          final recos = c.recommendations?.results ?? const [];
          final loading = c.loading && c.recommendations == null;
          return RefreshIndicator(
            onRefresh: c.load,
            edgeOffset: kToolbarHeight + MediaQuery.paddingOf(context).top,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                HeroCarousel(items: recos.take(5).toList(), loading: loading),
                if (!c.signedIn) const _SignInBanner(),
                SectionHeader(
                  c.isPersonal ? 'Recommended for you' : 'Popular right now',
                  subtitle: c.isPersonal
                      ? 'Based on your lists, favorites and ratings'
                      : 'Add movies to your lists to get personal picks',
                ),
                MovieRail(
                  items: recos.length > 5 ? recos.skip(5).toList() : recos,
                  loading: loading,
                ),
                const SectionHeader('Top 10 this week'),
                Top10Rail(movies: c.trending, loading: loading),
                if (c.signedIn) ...[
                  SectionHeader(
                    'My lists',
                    subtitle: '${c.myLists.length} lists',
                    onSeeAll: _openLists,
                  ),
                  _MyListsRail(lists: c.myLists, onCreate: _openLists),
                ],
                for (final row in c.genreRows) ...[
                  SectionHeader(row.name),
                  MovieRail(items: row.movies),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MyListsRail extends StatelessWidget {
  const _MyListsRail({required this.lists, required this.onCreate});

  final List<CustomList> lists;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: RecoUi.pagePadding,
        children: [
          _ListTileCard(
            title: 'New list',
            subtitle: 'Create',
            cover: const ListCover(posters: []),
            onTap: onCreate,
          ),
          for (final list in lists)
            _ListTileCard(
              title: list.name,
              subtitle: '${list.movieCount} movies',
              cover: ListCover(posters: list.previewPosters),
              onTap: () => context.push('/lists/${list.id}'),
            ),
        ],
      ),
    );
  }
}

class _ListTileCard extends StatelessWidget {
  const _ListTileCard({
    required this.title,
    required this.subtitle,
    required this.cover,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget cover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RecoUi.radius),
        child: SizedBox(
          width: 110,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 150, width: 110, child: cover),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignInBanner extends StatelessWidget {
  const _SignInBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.auto_awesome),
          title: const Text('Get personal recommendations'),
          subtitle: const Text('Sign in and build your lists.'),
          trailing: FilledButton(
            onPressed: () => context.push('/login'),
            child: const Text('Sign in'),
          ),
        ),
      ),
    );
  }
}
