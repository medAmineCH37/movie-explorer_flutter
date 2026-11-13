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

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      subscriptions = await _repository.getSubscriptions();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
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
    error = null;
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() action) async {
    isBusy = true;
    notifyListeners();

    try {
      await action();
    } finally {
      isBusy = false;
    }

    await load();
  }
}
