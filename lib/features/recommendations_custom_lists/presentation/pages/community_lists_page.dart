import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/custom_list_repository.dart';
import '../../domain/models/custom_list.dart';
import '../widgets/reco_ui.dart';
import 'my_lists_page.dart';
import '../../../../core/navigation/app_shell.dart';

/// Public lists of every user (read-only for non-owners).
class CommunityListsPage extends StatefulWidget {
  const CommunityListsPage({super.key});

  @override
  State<CommunityListsPage> createState() => _CommunityListsPageState();
}

class _CommunityListsPageState extends State<CommunityListsPage> {
  static const int _pageSize = 30;
  final CustomListRepository _repository = CustomListRepository();
  final List<CustomList> _lists = [];
  bool _loading = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_repository.currentUserId != null) _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _repository.getPublicLists(
        limit: _pageSize,
        offset: reset ? 0 : _lists.length,
      );
      if (reset) _lists.clear();
      _lists.addAll(page);
      _hasMore = page.length == _pageSize;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final me = _repository.currentUserId;
    return Scaffold(
      appBar: AppBar(
        leading: const ShellLeading(),
        leadingWidth: shellLeadingWidth(context),
        title: const Text(
          'Community lists',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: me == null
          ? Center(
              child: FilledButton(
                onPressed: () => context.push('/login'),
                child: const Text('Sign in to explore lists'),
              ),
            )
          : _error != null && _lists.isEmpty
          ? ErrorRetry(message: _error!, onRetry: () => _load(reset: true))
          : _loading && _lists.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: _lists.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 160),
                        Icon(Icons.public, size: 56, color: Colors.white38),
                        SizedBox(height: 12),
                        Text(
                          'No public list yet.\nMake one of your lists public to share it here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60),
                        ),
                      ],
                    )
                  : CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.all(16),
                          sliver: SliverGrid.builder(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 220,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 14,
                                  childAspectRatio: 0.58,
                                ),
                            itemCount: _lists.length,
                            itemBuilder: (context, i) {
                              final list = _lists[i];
                              return ListCard(
                                list: list,
                                showOwner: true,
                                onTap: () => context.push('/lists/${list.id}'),
                              );
                            },
                          ),
                        ),
                        if (_hasMore)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 32),
                              child: Center(
                                child: _loading
                                    ? const CircularProgressIndicator()
                                    : OutlinedButton(
                                        onPressed: _load,
                                        child: const Text('Load more'),
                                      ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
    );
  }
}
