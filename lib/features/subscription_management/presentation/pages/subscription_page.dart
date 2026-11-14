import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../user_management/data/services/auth_service.dart';
import '../../domain/models/subscription.dart';
import '../controllers/subscription_controller.dart';
import '../widgets/current_plan_card.dart';
import '../widgets/plan_card.dart';
import '../widgets/price_breakdown.dart';
import '../widgets/subscription_history.dart';
import '../../../../core/navigation/app_shell.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key, this.sessionId, this.checkout});

  final String? sessionId;
  final String? checkout;

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage>
    with WidgetsBindingObserver {
  final SubscriptionController _controller = SubscriptionController();
  final AuthService _authService = AuthService();
  late final StreamSubscription<AuthState> _authSubscription;

  bool get _isAuthenticated => _authService.currentUser != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_isAuthenticated) _start();
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
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final sessionId = widget.sessionId;
    final cancelled = widget.checkout == 'cancelled';

    if (sessionId == null && !cancelled) {
      await _controller.load();
      return;
    }

    if (cancelled) {
      await _controller.load();
      _show('Payment cancelled. You were not charged.');
      return;
    }

    try {
      await _controller.confirmCheckout(sessionId!);
      final current = _controller.current;
      _show(
        current == null
            ? 'Payment confirmed.'
            : 'Payment confirmed: ${formatMoney(current.amountPaid)}'
                  '${current.card == null ? '' : ' with ${current.card!.label}'}. '
                  'You are now on ${current.plan.label}.',
      );
    } catch (e) {
      await _controller.load();
      _show(_message(e));
    }
  }

  void _show(String message) {
    if (!mounted) return;
    if (widget.sessionId != null || widget.checkout != null) {
      context.go('/subscription');
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _message(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  /// Optional public web address of the app (e.g. a deployed web build).
  static const String _webAppUrl = String.fromEnvironment('APP_WEB_URL');

  /// Stripe session paid in the browser on mobile, confirmed when the user
  /// comes back to the app.
  String? _pendingSessionId;

  /// Where Stripe sends the user after paying. On the web, back to this page.
  /// On Android/iOS the app has no web address (`Uri.base` is `file:///`), so
  /// Stripe returns to an https page and the app confirms the payment itself
  /// when it is reopened.
  String get _returnUrl {
    if (kIsWeb) return '${Uri.base.origin}${Uri.base.path}#/subscription';
    return _webAppUrl.isNotEmpty
        ? '$_webAppUrl/#/subscription'
        : 'https://stripe.com/';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final sessionId = _pendingSessionId;
    if (state != AppLifecycleState.resumed || sessionId == null) return;
    _pendingSessionId = null;
    _confirmMobilePayment(sessionId);
  }

  Future<void> _confirmMobilePayment(String sessionId) async {
    try {
      await _controller.confirmCheckout(sessionId);
      final current = _controller.current;
      _show(
        current == null
            ? 'Payment confirmed.'
            : 'Payment confirmed. You are now on ${current.plan.label}.',
      );
    } catch (e) {
      await _controller.load();
      _show(_message(e));
    }
  }

  Future<void> _subscribe(SubscriptionPlan plan) async {
    final change = _controller.quote(plan);
    final needsPayment = change.total > 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          change.from == null
              ? 'Subscribe to ${plan.label}'
              : 'Switch to ${plan.label}?',
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PriceBreakdown(change: change),
              const SizedBox(height: 16),
              if (needsPayment)
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You will be redirected to Stripe to pay securely.',
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: Icon(needsPayment ? Icons.credit_card : Icons.swap_horiz),
            label: Text(
              needsPayment
                  ? 'Pay ${formatMoney(change.total)} with Stripe'
                  : 'Confirm switch',
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final result = await _controller.checkout(plan, _returnUrl);
      final url = result.url;
      if (url != null) {
        if (kIsWeb) {
          await launchUrl(Uri.parse(url), webOnlyWindowName: '_self');
        } else {
          // The checkout URL contains the Stripe session id (cs_...).
          _pendingSessionId = RegExp(r'cs_(?:test|live)_[A-Za-z0-9]+')
              .firstMatch(url)
              ?.group(0);
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
        return;
      }
      _show(
        result.refund > 0
            ? 'You are now on ${plan.label}. '
                  '${formatMoney(result.refund)} refunded to your card.'
            : 'You are now on ${plan.label}.',
      );
    } catch (e) {
      _show(_message(e));
    }
  }

  Future<void> _cancel() async {
    final current = _controller.current;
    if (current == null) return;
    final refund = current.unusedValue;
    final refundText = refund > 0
        ? '${formatMoney(refund)} for the ${current.unusedDays} unused days '
              'will be refunded to your card. '
        : '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel subscription?'),
        content: Text(
          'You used ${current.usedDays} of ${current.plan.durationDays} days. '
          '${refundText}Your Premium access ends now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              refund > 0
                  ? 'Cancel and refund ${formatMoney(refund)}'
                  : 'Cancel subscription',
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final refunded = await _controller.cancel();
      _show(
        refunded > 0
            ? 'Subscription cancelled. ${formatMoney(refunded)} refunded '
                  'to your card.'
            : 'Subscription cancelled.',
      );
    } catch (e) {
      _show(_message(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription'),
        leading: ShellLeading(onBack: () => context.go('/')),
        leadingWidth: shellLeadingWidth(context, customBack: true),
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
            children: _controller.isAdmin
                ? [
                    const _AdminAccessCard(),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => context.push('/admin/subscriptions'),
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: const Text('Manage all subscriptions'),
                    ),
                  ]
                : [
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
                        change: _controller.quote(plan),
                        isBusy: _controller.isBusy,
                        onSubscribe: () => _subscribe(plan),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 16),
                    Text('History', style: titleStyle),
                    const SizedBox(height: 8),
                    SubscriptionHistory(
                      subscriptions: _controller.subscriptions,
                    ),
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

class _AdminAccessCard extends StatelessWidget {
  const _AdminAccessCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.verified_user, color: Color(0xFFFFC857), size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin account',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'You have full Premium access. No subscription needed.',
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
