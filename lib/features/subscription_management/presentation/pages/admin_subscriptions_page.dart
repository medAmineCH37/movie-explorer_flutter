import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/subscription_service.dart';
import '../../domain/models/subscription.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../controllers/admin_subscription_controller.dart';
import '../widgets/admin_stats.dart';
import '../widgets/admin_subscription_tile.dart';
import '../widgets/grant_subscription_dialog.dart';

class AdminSubscriptionsPage extends StatefulWidget {
  const AdminSubscriptionsPage({super.key, this.repository});

  final AdminSubscriptionRepository? repository;

  @override
  State<AdminSubscriptionsPage> createState() => _AdminSubscriptionsPageState();
}

class _AdminSubscriptionsPageState extends State<AdminSubscriptionsPage> {
  late final AdminSubscriptionRepository _service =
      widget.repository ?? SubscriptionService();
  late final AdminSubscriptionController _controller =
      AdminSubscriptionController(repository: _service);
  bool? _isAdmin;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    bool isAdmin;
    try {
      isAdmin = await _service.isAdmin();
    } catch (_) {
      isAdmin = false;
    }
    if (!mounted) return;
    setState(() => _isAdmin = isAdmin);
    if (isAdmin) _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _perform(Future<void> Function() action, String message) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Action failed. Please try again.')),
      );
    }
  }

  Future<void> _onAction(Subscription subscription, AdminAction action) async {
    switch (action) {
      case AdminAction.extend:
        await _perform(
          () => _controller.extend(subscription, 30),
          'Subscription extended by 30 days.',
        );
      case AdminAction.cancel:
        await _perform(
          () => _controller.cancel(subscription),
          'Subscription will end on its end date.',
        );
      case AdminAction.endNow:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('End subscription now?'),
            content: Text(
              '${subscription.userName ?? 'This user'} will lose Premium '
              'access immediately.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Keep'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('End now'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        await _perform(
          () => _controller.endNow(subscription),
          'Subscription ended.',
        );
    }
  }

  Future<void> _grant() async {
    final result = await showDialog<GrantSubscriptionResult>(
      context: context,
      builder: (_) => GrantSubscriptionDialog(users: _controller.users),
    );
    if (result == null) return;
    await _perform(
      () => _controller.grant(result.userId, result.plan),
      '${result.plan.label} granted.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage subscriptions'),
        leading: IconButton(
          onPressed: () => context.go('/subscription'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
        ),
      ),
      floatingActionButton: _isAdmin == true
          ? FloatingActionButton.extended(
              onPressed: _grant,
              icon: const Icon(Icons.card_giftcard),
              label: const Text('Grant'),
            )
          : null,
      body: switch (_isAdmin) {
        null => const Center(child: CircularProgressIndicator()),
        false => _accessDenied(),
        true => _content(),
      },
    );
  }

  Widget _content() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isLoading && _controller.subscriptions.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_controller.error != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 48),
                const SizedBox(height: 12),
                const Text('Could not load subscriptions.'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _controller.load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          );
        }

        final visible = _controller.visible;

        return RefreshIndicator(
          onRefresh: _controller.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              AdminStats(
                active: _controller.activeCount,
                monthly: _controller.monthlyCount,
                yearly: _controller.yearlyCount,
                revenue: _controller.revenue,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search by user or plan',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: _controller.setQuery,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _controller.filter == null,
                    onSelected: (_) => _controller.setFilter(null),
                  ),
                  for (final state in SubscriptionState.values)
                    ChoiceChip(
                      label: Text(state.label),
                      selected: _controller.filter == state,
                      onSelected: (_) => _controller.setFilter(state),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No subscriptions found.')),
                ),
              for (final subscription in visible)
                AdminSubscriptionTile(
                  subscription: subscription,
                  isBusy: _controller.isBusy,
                  onAction: (action) => _onAction(subscription, action),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _accessDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.admin_panel_settings_outlined, size: 64),
            const SizedBox(height: 16),
            Text('Admins only', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'You need an admin account to manage subscriptions.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
