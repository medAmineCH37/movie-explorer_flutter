import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../user_management/data/auth_service.dart';
import '../../domain/models/subscription.dart';
import '../controllers/subscription_controller.dart';
import '../widgets/current_plan_card.dart';
import '../widgets/plan_card.dart';
import '../widgets/subscription_history.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final SubscriptionController _controller = SubscriptionController();
  final AuthService _authService = AuthService();
  late final StreamSubscription<AuthState> _authSubscription;

  bool get _isAuthenticated => _authService.currentUser != null;

  @override
  void initState() {
    super.initState();
    if (_isAuthenticated) _controller.load();
    _authSubscription = _authService.authStateChanges.listen((data) {
      if (!mounted) return;
      if (data.event == AuthChangeEvent.signedIn) {
        setState(() {});
        _controller.load();
      } else if (data.event == AuthChangeEvent.signedOut) {
        setState(() {});
        _controller.clear();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _subscribe(SubscriptionPlan plan) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _controller.subscribe(plan);
      messenger.showSnackBar(
        SnackBar(content: Text('You are now on ${plan.label}.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not subscribe. Please try again.')),
      );
    }
  }

  Future<void> _cancel() async {
    final current = _controller.current;
    if (current == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel subscription?'),
        content: const Text(
          'You will keep Premium access until the end of the current period.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel subscription'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _controller.cancel();
      messenger.showSnackBar(
        const SnackBar(content: Text('Subscription cancelled.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not cancel. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription'),
        leading: IconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to home',
        ),
        actions: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => _controller.isAdmin
                ? IconButton(
                    onPressed: () => context.push('/admin/subscriptions'),
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    tooltip: 'Manage subscriptions',
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: _isAuthenticated ? _content() : _signIn(),
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
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Could not load your subscription.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _controller.load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        }

        final titleStyle = Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.bold);

        return RefreshIndicator(
          onRefresh: _controller.load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              CurrentPlanCard(
                subscription: _controller.current,
                isBusy: _controller.isBusy,
                onCancel: _cancel,
              ),
              const SizedBox(height: 24),
              Text('Plans', style: titleStyle),
              const SizedBox(height: 8),
              for (final plan in SubscriptionPlan.values) ...[
                PlanCard(
                  plan: plan,
                  currentPlan: _controller.currentPlan,
                  isBusy: _controller.isBusy,
                  onSubscribe: () => _subscribe(plan),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 16),
              Text('History', style: titleStyle),
              const SizedBox(height: 8),
              SubscriptionHistory(subscriptions: _controller.history),
            ],
          ),
        );
      },
    );
  }

  Widget _signIn() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 64),
            const SizedBox(height: 20),
            Text(
              'Sign in to manage your subscription',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Choose a plan and manage your Premium access from your account.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.push(
                '/login?redirect=${Uri.encodeComponent('/subscription')}',
              ),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
