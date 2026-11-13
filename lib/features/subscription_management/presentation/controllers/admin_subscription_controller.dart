import 'package:flutter/foundation.dart';

import '../../data/subscription_service.dart';
import '../../domain/models/subscription.dart';
import '../../domain/repositories/subscription_repository.dart';

class AdminSubscriptionController extends ChangeNotifier {
  AdminSubscriptionController({AdminSubscriptionRepository? repository})
    : _repository = repository ?? SubscriptionService();

  final AdminSubscriptionRepository _repository;

  List<Subscription> subscriptions = [];
  List<AppUser> users = [];
  SubscriptionState? filter;
  String query = '';
  bool isLoading = false;
  bool isBusy = false;
  String? error;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  List<Subscription> get visible => subscriptions.where((subscription) {
    final matchesFilter = filter == null || subscription.state == filter;
    final matchesQuery =
        query.isEmpty ||
        (subscription.userName ?? '').toLowerCase().contains(query) ||
        subscription.plan.label.toLowerCase().contains(query);
    return matchesFilter && matchesQuery;
  }).toList();

  List<Subscription> get _current =>
      subscriptions.where((subscription) => subscription.isActive).toList();

  int get activeCount => _current.length;

  int get monthlyCount => _current
      .where((subscription) => subscription.plan == SubscriptionPlan.monthly)
      .length;

  int get yearlyCount => _current
      .where((subscription) => subscription.plan == SubscriptionPlan.yearly)
      .length;

  double get revenue => roundMoney(
    subscriptions.fold(
      0,
      (total, subscription) => total + subscription.netPaid,
    ),
  );

  void setFilter(SubscriptionState? value) {
    filter = value;
    _notify();
  }

  void setQuery(String value) {
    query = value.trim().toLowerCase();
    _notify();
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    _notify();

    try {
      final results = await Future.wait([
        _repository.getAllSubscriptions(),
        _repository.getUsers(),
      ]);
      subscriptions = results[0] as List<Subscription>;
      users = results[1] as List<AppUser>;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      _notify();
    }
  }

  Future<void> grant(String userId, SubscriptionPlan plan) =>
      _run(() => _repository.grant(userId, plan));

  Future<double> endSubscription(
    Subscription subscription, {
    required bool refund,
  }) async {
    var refunded = 0.0;
    await _run(
      () async => refunded = await _repository.endSubscription(
        subscription.id,
        refund: refund,
      ),
    );
    return refunded;
  }

  Future<void> extend(Subscription subscription, int days) =>
      _run(() => _repository.extend(subscription, days));

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
