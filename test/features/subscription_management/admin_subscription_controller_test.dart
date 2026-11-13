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

  Subscription _copy(
    Subscription s, {
    String? status,
    DateTime? endsAt,
    double? refundAmount,
  }) => Subscription(
    id: s.id,
    plan: s.plan,
    status: status ?? s.status,
    startedAt: s.startedAt,
    endsAt: endsAt ?? s.endsAt,
    amountPaid: s.amountPaid,
    refundAmount: refundAmount ?? s.refundAmount,
    userId: s.userId,
    userName: s.userName,
  );

  void _update(int id, Subscription Function(Subscription) change) {
    final index = rows.indexWhere((row) => row.id == id);
    rows[index] = change(rows[index]);
  }

  void addPaid(String userId, SubscriptionPlan plan, {double refund = 0}) {
    final now = DateTime.now().subtract(const Duration(minutes: 1));
    rows.add(
      Subscription(
        id: _nextId++,
        plan: plan,
        status: 'active',
        startedAt: now,
        endsAt: now.add(Duration(days: plan.durationDays)),
        amountPaid: plan.price,
        refundAmount: refund,
        userId: userId,
        userName: people.firstWhere((p) => p.id == userId).name,
      ),
    );
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
  Future<double> endSubscription(
    int subscriptionId, {
    required bool refund,
  }) async {
    final row = rows.firstWhere((r) => r.id == subscriptionId);
    final amount = refund ? row.unusedValue : 0.0;
    _update(
      subscriptionId,
      (s) => _copy(
        s,
        status: 'cancelled',
        endsAt: DateTime.now(),
        refundAmount: s.refundAmount + amount,
      ),
    );
    return amount;
  }

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
    repository.addPaid('u1', SubscriptionPlan.monthly);
    repository.addPaid('u2', SubscriptionPlan.yearly);

    await controller.load();

    expect(controller.subscriptions, hasLength(2));
    expect(controller.users, hasLength(2));
    expect(controller.activeCount, 2);
    expect(controller.monthlyCount, 1);
    expect(controller.yearlyCount, 1);
    expect(controller.revenue, closeTo(32.98, 0.001));
  });

  test('revenue subtracts refunds and ignores free grants', () async {
    repository.addPaid('u1', SubscriptionPlan.yearly, refund: 10);
    await repository.grant('u2', SubscriptionPlan.monthly);

    await controller.load();

    expect(controller.revenue, closeTo(19.99, 0.001));
  });

  test('grants a plan and replaces the active one', () async {
    await controller.grant('u1', SubscriptionPlan.monthly);
    await controller.grant('u1', SubscriptionPlan.yearly);

    expect(controller.activeCount, 1);
    expect(controller.yearlyCount, 1);
    expect(controller.subscriptions, hasLength(2));
  });

  test('cancel and refund gives back the unused days', () async {
    repository.addPaid('u1', SubscriptionPlan.yearly);
    await controller.load();

    final refund = await controller.endSubscription(
      controller.subscriptions.first,
      refund: true,
    );

    expect(refund, 29.91);
    expect(controller.subscriptions.first.state, SubscriptionState.cancelled);
    expect(controller.subscriptions.first.refundAmount, 29.91);
    expect(controller.activeCount, 0);
  });

  test('revoking ends access without a refund', () async {
    repository.addPaid('u1', SubscriptionPlan.monthly);
    await controller.load();

    final refund = await controller.endSubscription(
      controller.subscriptions.first,
      refund: false,
    );

    expect(refund, 0);
    expect(controller.subscriptions.first.state, SubscriptionState.cancelled);
    expect(controller.revenue, 2.99);
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
    await controller.endSubscription(
      controller.subscriptions.firstWhere((s) => s.userId == 'u2'),
      refund: false,
    );

    controller.setFilter(SubscriptionState.cancelled);
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
      repository.addPaid('u1', SubscriptionPlan.monthly);
      repository.addPaid('u2', SubscriptionPlan.yearly);

      await pumpPage(tester);

      expect(find.text('Active subscribers'), findsOneWidget);
      expect(find.text('32.98 €'), findsOneWidget);
      expect(find.text('Olfa'), findsOneWidget);
      expect(find.text('Amine'), findsOneWidget);
    });

    testWidgets('revokes a subscription from the menu', (tester) async {
      repository.addPaid('u1', SubscriptionPlan.monthly);

      await pumpPage(tester);
      await tester.tap(find.byTooltip('Manage'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revoke access (no refund)'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Revoke'));
      await tester.pumpAndSettle();

      expect(repository.rows.single.isActive, isFalse);
      expect(repository.rows.single.refundAmount, 0);
      expect(find.text('Access revoked.'), findsOneWidget);
    });

    testWidgets('cancels with a refund from the menu', (tester) async {
      repository.addPaid('u1', SubscriptionPlan.yearly);

      await pumpPage(tester);
      await tester.tap(find.byTooltip('Manage'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel and refund (29.91 €)'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel and refund'));
      await tester.pumpAndSettle();

      expect(repository.rows.single.isActive, isFalse);
      expect(repository.rows.single.refundAmount, 29.91);
      expect(
        find.text('Subscription cancelled. 29.91 € refunded.'),
        findsOneWidget,
      );
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
