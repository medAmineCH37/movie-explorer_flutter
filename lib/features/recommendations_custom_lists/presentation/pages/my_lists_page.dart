import '../../../../core/navigation/app_shell.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/list_rules.dart';
import '../../domain/models/custom_list.dart';
import '../controllers/my_lists_controller.dart';
import '../widgets/list_form_sheet.dart';
import '../widgets/reco_ui.dart';

class MyListsPage extends StatefulWidget {
  const MyListsPage({super.key});

  @override
  State<MyListsPage> createState() => _MyListsPageState();
}

class _MyListsPageState extends State<MyListsPage> {
  final MyListsController _controller = MyListsController();

  @override
  void initState() {
    super.initState();
    if (_controller.repository.currentUserId != null) _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final limit = ListRules.canCreateList(_controller.lists.length);
    if (limit != null) {
      showRecoSnack(context, limit, error: true);
      return;
    }
    final form = await showListFormSheet(
      context,
      otherNames: _controller.lists.map((l) => l.name),
    );
    if (form == null || !mounted) return;
    try {
      final list = await _controller.create(
        form.name,
        form.description,
        form.isPublic,
      );
      if (!mounted) return;
      showRecoSnack(context, 'List "${list.name}" created');
      await _open(list);
    } catch (e) {
      if (mounted) showRecoSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _open(CustomList list) async {
    await context.push('/lists/${list.id}');
    if (mounted) await _controller.load();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.repository.currentUserId == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const ShellLeading(),

          leadingWidth: shellLeadingWidth(context),
          title: const Text('My lists'),
        ),
        body: Center(
          child: FilledButton(
            onPressed: () => context.push('/login'),
            child: const Text('Sign in to create lists'),
          ),
        ),
      );
    }
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final c = _controller;
        final visible = c.visible;
        return Scaffold(
          appBar: AppBar(
            leading: const ShellLeading(),

            leadingWidth: shellLeadingWidth(context),
            title: const Text(
              'My lists',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            actions: [
              PopupMenuButton<ListSort>(
                tooltip: 'Sort',
                icon: const Icon(Icons.sort),
                initialValue: c.sort,
                onSelected: c.setSort,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: ListSort.recent,
                    child: Text('Recently updated'),
                  ),
                  PopupMenuItem(
                    value: ListSort.name,
                    child: Text('Name (A–Z)'),
                  ),
                  PopupMenuItem(
                    value: ListSort.size,
                    child: Text('Most movies'),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _create,
            icon: const Icon(Icons.add),
            label: const Text('New list'),
          ),
          body: c.loading && c.lists.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : c.error != null
              ? ErrorRetry(message: c.error!, onRetry: c.load)
              : RefreshIndicator(
                  onRefresh: c.load,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: SegmentedButton<ListFilter>(
                                  showSelectedIcon: false,
                                  segments: const [
                                    ButtonSegment(
                                      value: ListFilter.all,
                                      label: Text('All'),
                                    ),
                                    ButtonSegment(
                                      value: ListFilter.private,
                                      label: Text('Private'),
                                      icon: Icon(Icons.lock_outline, size: 16),
                                    ),
                                    ButtonSegment(
                                      value: ListFilter.public,
                                      label: Text('Public'),
                                      icon: Icon(Icons.public, size: 16),
                                    ),
                                  ],
                                  selected: {c.filter},
                                  onSelectionChanged: (s) =>
                                      c.setFilter(s.first),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          child: Text(
                            '${c.lists.length}/${ListRules.maxLists} lists',
                            style: const TextStyle(color: Colors.white54),
                          ),
                        ),
                      ),
                      if (visible.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyLists(
                            filtered: c.lists.isNotEmpty,
                            onCreate: _create,
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                          sliver: SliverGrid.builder(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 220,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 14,
                                  childAspectRatio: 0.58,
                                ),
                            itemCount: visible.length,
                            itemBuilder: (context, i) => ListCard(
                              list: visible[i],
                              onTap: () => _open(visible[i]),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class ListCard extends StatelessWidget {
  const ListCard({
    required this.list,
    required this.onTap,
    super.key,
    this.showOwner = false,
  });

  final CustomList list;
  final VoidCallback onTap;
  final bool showOwner;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RecoUi.radius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ListCover(posters: list.previewPosters),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    radius: 13,
                    backgroundColor: Colors.black54,
                    child: Icon(
                      list.isPublic ? Icons.public : Icons.lock_outline,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            list.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            showOwner && list.ownerName != null
                ? 'by ${list.ownerName} · ${list.movieCount} movies'
                : '${list.movieCount} movies',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _EmptyLists extends StatelessWidget {
  const _EmptyLists({required this.filtered, required this.onCreate});

  final bool filtered;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            filtered ? 'No list matches this filter' : 'Create your first list',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Group movies by mood, genre or occasion. Your lists also improve your recommendations.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60),
          ),
          if (!filtered) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('New list'),
            ),
          ],
        ],
      ),
    );
  }
}
