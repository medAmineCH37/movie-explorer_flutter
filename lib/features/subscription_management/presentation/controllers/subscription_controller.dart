import 'package:flutter/foundation.dart';

import '../../data/subscription_service.dart';
import '../../domain/models/subscription.dart';
import '../../domain/repositories/subscription_repository.dart';

class SubscriptionController extends ChangeNotifier {
  SubscriptionController({SubscriptionRepository? repository})
    : _repository = repository ?? SubscriptionService();

  final SubscriptionRepository _repository;

  List<Subscription> subscriptions = [];
  bool isLoading = false;
  bool isBusy = false;
  bool isAdmin = false;
  String? error;

  Subscription? get current {
    for (final subscription in subscriptions) {
      if (subscription.isActive) return subscription;
    }
    return null;
  }

  SubscriptionPlan get currentPlan => current?.plan ?? SubscriptionPlan.free;

  List<Subscription> get history =>
      subscriptions.where((subscription) => subscription != current).toList();

  PlanChange quote(SubscriptionPlan plan) => PlanChange.to(plan, current);

  bool _disposed = false;

  Future<void> load() async {
    isLoading = true;
    error = null;
    _notify();

    final adminCheck = _repository.isAdmin().then<bool?>(
      (value) => value,
      onError: (Object _) => null,
    );

    try {
      subscriptions = await _repository.getSubscriptions();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
    }

    final admin = await adminCheck;
    if (admin != null) isAdmin = admin;
    _notify();
  }

  Future<CheckoutResult> checkout(
    SubscriptionPlan plan,
    String returnUrl,
  ) async {
    if (isAdmin) return const CheckoutResult();
    isBusy = true;
    _notify();

    try {
      final result = await _repository.checkout(plan, returnUrl);
      if (result.url == null) await load();
      return result;
    } finally {
      isBusy = false;
      _notify();
    }
  }

  Future<void> confirmCheckout(String sessionId) =>
      _run(() => _repository.confirmCheckout(sessionId));

  Future<double> cancel() async {
    final subscription = current;
    if (subscription == null || subscription.isCancelled) return 0;
    var refund = 0.0;
    await _run(() async => refund = await _repository.cancelWithRefund());
    return refund;
  }

  void clear() {
    subscriptions = [];
    isAdmin = false;
    error = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    isBusy = true;
    _notify();

    try {
      await action();
    } finally {
      isBusy = false;
    }

    await load();
  }
}
