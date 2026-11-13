import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movie_explorer/features/subscription_management/domain/models/subscription.dart';
import 'package:movie_explorer/features/subscription_management/domain/repositories/subscription_repository.dart';
import 'package:movie_explorer/features/subscription_management/presentation/controllers/admin_subscription_controller.dart';
import 'package:movie_explorer/features/subscription_management/presentation/pages/admin_subscriptions_page.dart';

class FakeAdminRepository implements AdminSubscriptionRepository {
  final List<Subscription> rows = [];
  final List<AppUser> people = const [
    AppUser(id: 'u1', name: 'Olfa'),
    AppUser(id: 'u2', name: 'Amine'),
  ];
  int _nextId = 1;
  bool shouldThrow = false;
  bool admin = true;

  @override
  Future<bool> isAdmin() async => admin;

  Subscription _copy(Subscription s, {String? status, DateTime? endsAt}) =>
      Subscription(
        id: s.id,
        plan: s.plan,
        status: status ?? s.status,
        startedAt: s.startedAt,
        endsAt: endsAt ?? s.endsAt,
        userId: s.userId,
        userName: s.userName,
      );

  void _update(int id, Subscription Function(Subscription) change) {
    final index = rows.indexWhere((row) => row.id == id);
    rows[index] = change(rows[index]);
  }

  @override
  Future<List<Subscription>> getAllSubscriptions() async {
    if (shouldThrow) throw Exception('Repository error');
    return [...rows];
  }

  @override
  Future<List<AppUser>> getUsers() async => people;

  @override
  Future<void> grant(String userId, SubscriptionPlan plan) async {
    final now = DateTime.now();
    for (final row in [...rows]) {
      if (row.userId == userId && row.isActive) {
        _update(row.id, (s) => _copy(s, status: 'cancelled', endsAt: now));
      }
    }
    rows.add(
      Subscription(
        id: _nextId++,
        plan: plan,
        status: 'active',
        startedAt: now,
        endsAt: now.add(Duration(days: plan.durationDays)),
        userId: userId,
        userName: people.firstWhere((p) => p.id == userId).name,
      ),
    );
  }

  @override
  Future<void> cancel(int subscriptionId) async =>
      _update(subscriptionId, (s) => _copy(s, status: 'cancelled'));

  @override
  Future<void> endNow(int subscriptionId) async => _update(
    subscriptionId,
    (s) => _copy(s, status: 'cancelled', endsAt: DateTime.now()),
  );

  @override
  Future<void> extend(Subscription subscription, int days) async => _update(
    subscription.id,
    (s) => _copy(s, endsAt: s.endsAt.add(Duration(days: days))),
  );
}

void main() {
  late FakeAdminRepository repository;
  late AdminSubscriptionController controller;

  setUp(() {
    repository = FakeAdminRepository();
    controller = AdminSubscriptionController(repository: repository);
  });

  test('loads all subscriptions and users', () async {
    await repository.grant('u1', SubscriptionPlan.monthly);
    await repository.grant('u2', SubscriptionPlan.yearly);

    await controller.load();

    expect(controller.subscriptions, hasLength(2));
    expect(controller.users, hasLength(2));
    expect(controller.activeCount, 2);
    expect(controller.monthlyCount, 1);
    expect(controller.yearlyCount, 1);
    expect(controller.revenue, closeTo(109.98, 0.001));
  });

  test('grants a plan and replaces the active one', () async {
    await controller.grant('u1', SubscriptionPlan.monthly);
    await controller.grant('u1', SubscriptionPlan.yearly);

    expect(controller.activeCount, 1);
    expect(controller.yearlyCount, 1);
    expect(controller.subscriptions, hasLength(2));
  });

  test('cancel keeps access, end now removes it', () async {
    await controller.grant('u1', SubscriptionPlan.monthly);
    final subscription = controller.subscriptions.first;

    await controller.cancel(subscription);
    expect(controller.subscriptions.first.state, SubscriptionState.cancelled);

    await controller.endNow(controller.subscriptions.first);
    expect(controller.subscriptions.first.state, SubscriptionState.expired);
    expect(controller.activeCount, 0);
  });

  test('extends a subscription', () async {
    await controller.grant('u2', SubscriptionPlan.monthly);
    final before = controller.subscriptions.first.daysLeft;

    await controller.extend(controller.subscriptions.first, 30);

    expect(controller.subscriptions.first.daysLeft, before + 30);
  });

  test('filters by state and searches by user', () async {
    await controller.grant('u1', SubscriptionPlan.monthly);
    await controller.grant('u2', SubscriptionPlan.yearly);
    await controller.endNow(
      controller.subscriptions.firstWhere((s) => s.userId == 'u2'),
    );

    controller.setFilter(SubscriptionState.expired);
    expect(controller.visible.single.userName, 'Amine');

    controller.setFilter(null);
    controller.setQuery('olf');
    expect(controller.visible.single.userName, 'Olfa');
  });

  test('stores an error when loading fails', () async {
    repository.shouldThrow = true;

    await controller.load();

    expect(controller.error, isNotNull);
  });

  group('AdminSubscriptionsPage', () {
    Future<void> pumpPage(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: AdminSubscriptionsPage(repository: repository)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('blocks users who are not admins', (tester) async {
      repository.admin = false;

      await pumpPage(tester);

      expect(find.text('Admins only'), findsOneWidget);
      expect(find.text('Grant'), findsNothing);
    });

    testWidgets('shows stats and subscriptions', (tester) async {
      await repository.grant('u1', SubscriptionPlan.monthly);
      await repository.grant('u2', SubscriptionPlan.yearly);

      await pumpPage(tester);

      expect(find.text('Active subscribers'), findsOneWidget);
      expect(find.text('109.98 TND'), findsOneWidget);
      expect(find.text('Olfa'), findsOneWidget);
      expect(find.text('Amine'), findsOneWidget);
    });

    testWidgets('ends a subscription from the menu', (tester) async {
      await repository.grant('u1', SubscriptionPlan.monthly);

      await pumpPage(tester);
      await tester.tap(find.byTooltip('Manage'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('End now').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'End now'));
      await tester.pumpAndSettle();

      expect(repository.rows.single.isActive, isFalse);
      expect(find.text('Expired'), findsWidgets);
    });

    testWidgets('grants a plan from the dialog', (tester) async {
      await pumpPage(tester);
      await tester.tap(find.text('Grant'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('User'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amine').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Grant'));
      await tester.pumpAndSettle();

      expect(repository.rows.single.userId, 'u2');
      expect(repository.rows.single.plan, SubscriptionPlan.monthly);
      expect(find.text('Amine'), findsOneWidget);
    });
  });
}
