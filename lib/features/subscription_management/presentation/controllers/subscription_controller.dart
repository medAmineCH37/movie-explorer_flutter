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

  Future<void> subscribe(SubscriptionPlan plan) async {
    await _run(() => _repository.subscribe(plan));
  }

  Future<void> cancel() async {
    final subscription = current;
    if (subscription == null || subscription.isCancelled) return;
    await _run(() => _repository.cancel(subscription.id));
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
