import 'package:flutter_test/flutter_test.dart';

import 'package:movie_explorer/features/subscription_management/domain/models/subscription.dart';
import 'package:movie_explorer/features/subscription_management/domain/repositories/subscription_repository.dart';
import 'package:movie_explorer/features/subscription_management/presentation/controllers/subscription_controller.dart';

class FakeSubscriptionRepository implements SubscriptionRepository {
  final List<Subscription> rows = [];
  int _nextId = 1;
  bool shouldThrow = false;

  @override
  Future<List<Subscription>> getSubscriptions() async {
    if (shouldThrow) throw Exception('Repository error');
    final sorted = [...rows]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sorted;
  }

  @override
  Future<void> subscribe(SubscriptionPlan plan) async {
    if (shouldThrow) throw Exception('Repository error');
    final now = DateTime.now();
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].isActive) {
        rows[i] = Subscription(
          id: rows[i].id,
          plan: rows[i].plan,
          status: 'cancelled',
          startedAt: rows[i].startedAt,
          endsAt: now,
        );
      }
    }
    rows.add(
      Subscription(
        id: _nextId++,
        plan: plan,
        status: 'active',
        startedAt: now.add(const Duration(milliseconds: 1)),
        endsAt: now.add(Duration(days: plan.durationDays)),
      ),
    );
  }

  @override
  Future<void> cancel(int subscriptionId) async {
    if (shouldThrow) throw Exception('Repository error');
    final index = rows.indexWhere((row) => row.id == subscriptionId);
    final row = rows[index];
    rows[index] = Subscription(
      id: row.id,
      plan: row.plan,
      status: 'cancelled',
      startedAt: row.startedAt,
      endsAt: row.endsAt,
    );
  }
}

void main() {
  late FakeSubscriptionRepository repository;
  late SubscriptionController controller;

  setUp(() {
    repository = FakeSubscriptionRepository();
    controller = SubscriptionController(repository: repository);
  });

  group('SubscriptionController', () {
    test('defaults to the free plan without subscriptions', () async {
      await controller.load();

      expect(controller.current, isNull);
      expect(controller.currentPlan, SubscriptionPlan.free);
      expect(controller.history, isEmpty);
    });

    test('subscribes to a paid plan', () async {
      await controller.subscribe(SubscriptionPlan.monthly);

      expect(controller.currentPlan, SubscriptionPlan.monthly);
      expect(controller.current!.daysLeft, 30);
      expect(controller.current!.isCancelled, isFalse);
    });

    test('switching plans moves the old plan to history', () async {
      await controller.subscribe(SubscriptionPlan.monthly);
      await controller.subscribe(SubscriptionPlan.yearly);

      expect(controller.currentPlan, SubscriptionPlan.yearly);
      expect(controller.history, hasLength(1));
      expect(controller.history.first.plan, SubscriptionPlan.monthly);
      expect(controller.history.first.isCancelled, isTrue);
    });

    test('cancelling keeps access until the end date', () async {
      await controller.subscribe(SubscriptionPlan.yearly);
      await controller.cancel();

      expect(controller.currentPlan, SubscriptionPlan.yearly);
      expect(controller.current!.isCancelled, isTrue);
      expect(controller.current!.isActive, isTrue);
    });

    test('expired subscriptions fall back to free', () async {
      final now = DateTime.now();
      repository.rows.add(
        Subscription(
          id: 99,
          plan: SubscriptionPlan.monthly,
          status: 'active',
          startedAt: now.subtract(const Duration(days: 40)),
          endsAt: now.subtract(const Duration(days: 10)),
        ),
      );

      await controller.load();

      expect(controller.currentPlan, SubscriptionPlan.free);
      expect(controller.history, hasLength(1));
    });

    test('stores an error when loading fails', () async {
      repository.shouldThrow = true;

      await controller.load();

      expect(controller.error, isNotNull);
      expect(controller.isLoading, isFalse);
    });
  });

  test('plan values map back to plans', () {
    expect(SubscriptionPlan.fromValue('yearly'), SubscriptionPlan.yearly);
    expect(SubscriptionPlan.fromValue('unknown'), SubscriptionPlan.free);
  });
}
