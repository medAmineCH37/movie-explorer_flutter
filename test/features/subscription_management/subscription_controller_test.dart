import 'package:flutter_test/flutter_test.dart';

import 'package:movie_explorer/features/subscription_management/domain/models/subscription.dart';
import 'package:movie_explorer/features/subscription_management/domain/repositories/subscription_repository.dart';
import 'package:movie_explorer/features/subscription_management/presentation/controllers/subscription_controller.dart';

class FakeSubscriptionRepository implements SubscriptionRepository {
  final List<Subscription> rows = [];
  final Map<String, PlanChange> sessions = {};
  int _nextId = 1;
  bool shouldThrow = false;
  bool admin = false;
  bool adminCheckFails = false;

  Subscription? get _current {
    final active = rows.where((row) => row.isActive).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return active.isEmpty ? null : active.first;
  }

  void _end(Subscription row, double refund) {
    final index = rows.indexWhere((r) => r.id == row.id);
    rows[index] = Subscription(
      id: row.id,
      plan: row.plan,
      status: 'cancelled',
      startedAt: row.startedAt,
      endsAt: DateTime.now(),
      amountPaid: row.amountPaid,
      refundAmount: row.refundAmount + refund,
      cardBrand: row.cardBrand,
      cardLast4: row.cardLast4,
    );
  }

  void _insert(
    SubscriptionPlan plan,
    double amount, {
    double credit = 0,
    bool card = false,
  }) {
    final now = DateTime.now().subtract(const Duration(minutes: 1));
    rows.add(
      Subscription(
        id: _nextId++,
        plan: plan,
        status: 'active',
        startedAt: now.add(const Duration(milliseconds: 1)),
        endsAt: now.add(Duration(days: plan.durationDays)),
        amountPaid: amount,
        creditApplied: credit,
        cardBrand: card ? 'Visa' : null,
        cardLast4: card ? '4242' : null,
      ),
    );
  }

  @override
  Future<bool> isAdmin() async {
    if (adminCheckFails) throw Exception('Network error');
    return admin;
  }

  @override
  Future<List<Subscription>> getSubscriptions() async {
    if (shouldThrow) throw Exception('Repository error');
    return [...rows]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  @override
  Future<CheckoutResult> checkout(
    SubscriptionPlan plan,
    String returnUrl,
  ) async {
    if (shouldThrow) throw Exception('Repository error');
    final change = PlanChange.to(plan, _current);
    if (change.total > 0) {
      final id = 'cs_test_${sessions.length + 1}';
      sessions[id] = change;
      return CheckoutResult(url: 'https://checkout.stripe.com/c/pay/$id');
    }
    _end(change.from!, change.refund);
    _insert(plan, 0, credit: plan.price);
    return CheckoutResult(refund: change.refund);
  }

  @override
  Future<void> confirmCheckout(String sessionId) async {
    final change = sessions.remove(sessionId);
    if (change == null) throw Exception('The payment was not completed.');
    if (change.from != null) _end(change.from!, 0);
    _insert(
      change.plan,
      change.total,
      credit: roundMoney(change.plan.price - change.total),
      card: true,
    );
  }

  @override
  Future<double> cancelWithRefund() async {
    if (shouldThrow) throw Exception('Repository error');
    final current = _current!;
    final refund = current.unusedValue;
    _end(current, refund);
    return refund;
  }
}

void main() {
  late FakeSubscriptionRepository repository;
  late SubscriptionController controller;

  const returnUrl = 'http://localhost/#/subscription';

  Future<void> payFor(SubscriptionPlan plan) async {
    final result = await controller.checkout(plan, returnUrl);
    await controller.confirmCheckout(result.url!.split('/').last);
  }

  void addRunning(SubscriptionPlan plan, {required int daysLeft}) {
    final endsAt = DateTime.now().add(Duration(days: daysLeft, hours: 1));
    repository.rows.add(
      Subscription(
        id: 50,
        plan: plan,
        status: 'active',
        startedAt: endsAt.subtract(Duration(days: plan.durationDays)),
        endsAt: endsAt,
        amountPaid: plan.price,
      ),
    );
  }

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

    test('paid plans go through Stripe checkout first', () async {
      final result = await controller.checkout(
        SubscriptionPlan.monthly,
        returnUrl,
      );

      expect(result.url, startsWith('https://checkout.stripe.com/'));
      expect(controller.currentPlan, SubscriptionPlan.free);
    });

    test('a confirmed payment activates the plan', () async {
      await payFor(SubscriptionPlan.monthly);

      expect(controller.currentPlan, SubscriptionPlan.monthly);
      expect(controller.current!.daysLeft, 30);
      expect(controller.current!.amountPaid, 2.99);
      expect(controller.current!.card!.label, 'Visa •••• 4242');
    });

    test('an unpaid session is rejected', () async {
      await expectLater(
        controller.confirmCheckout('cs_test_unknown'),
        throwsException,
      );
      expect(controller.currentPlan, SubscriptionPlan.free);
    });

    test('upgrading only charges the difference for unused days', () async {
      addRunning(SubscriptionPlan.monthly, daysLeft: 20);
      await controller.load();

      final change = controller.quote(SubscriptionPlan.yearly);

      expect(change.isUpgrade, isTrue);
      expect(change.credit, 1.99);
      expect(change.total, 28.00);
      expect(change.refund, 0);

      await payFor(SubscriptionPlan.yearly);
      expect(controller.current!.plan, SubscriptionPlan.yearly);
      expect(controller.current!.amountPaid, 28.00);
      expect(controller.history.single.plan, SubscriptionPlan.monthly);
    });

    test('downgrading switches without payment and refunds', () async {
      addRunning(SubscriptionPlan.yearly, daysLeft: 300);
      await controller.load();

      final change = controller.quote(SubscriptionPlan.monthly);
      expect(change.isDowngrade, isTrue);
      expect(change.credit, 24.65);
      expect(change.total, 0);
      expect(change.refund, 21.66);

      final result = await controller.checkout(
        SubscriptionPlan.monthly,
        returnUrl,
      );

      expect(result.url, isNull);
      expect(result.refund, 21.66);
      expect(controller.currentPlan, SubscriptionPlan.monthly);
      expect(controller.history.single.refundAmount, 21.66);
    });

    test('cancelling a plan paid with credit still refunds', () async {
      addRunning(SubscriptionPlan.yearly, daysLeft: 300);
      await controller.load();
      await controller.checkout(SubscriptionPlan.monthly, returnUrl);

      expect(controller.current!.amountPaid, 0);
      expect(controller.current!.creditApplied, 2.99);

      final refund = await controller.cancel();

      expect(refund, 2.89);
    });

    test('cancelling after an upgrade refunds the whole plan value', () async {
      addRunning(SubscriptionPlan.monthly, daysLeft: 20);
      await controller.load();
      await payFor(SubscriptionPlan.yearly);

      expect(controller.current!.creditApplied, 1.99);

      final refund = await controller.cancel();

      expect(refund, 29.91);
    });

    test('small differences are charged the Stripe minimum', () async {
      addRunning(SubscriptionPlan.yearly, daysLeft: 34);
      await controller.load();

      final change = controller.quote(SubscriptionPlan.monthly);

      expect(change.credit, 2.79);
      expect(change.total, minimumCharge);
    });

    test('cancelling refunds the unused days and ends access', () async {
      addRunning(SubscriptionPlan.monthly, daysLeft: 20);
      await controller.load();

      final refund = await controller.cancel();

      expect(refund, 1.99);
      expect(controller.currentPlan, SubscriptionPlan.free);
      expect(controller.history.single.refundAmount, 1.99);
      expect(controller.history.single.netPaid, 1.00);
    });

    test('a cancelled plan is never current, even with a clock gap', () async {
      repository.rows.add(
        Subscription(
          id: 70,
          plan: SubscriptionPlan.yearly,
          status: 'cancelled',
          startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
          endsAt: DateTime.now().add(const Duration(minutes: 1)),
          amountPaid: 29.99,
          refundAmount: 29.91,
        ),
      );
      await controller.load();

      expect(controller.currentPlan, SubscriptionPlan.free);
      expect(controller.quote(SubscriptionPlan.yearly).total, 29.99);
    });

    test('free admin grants give no credit', () async {
      repository.rows.add(
        Subscription(
          id: 60,
          plan: SubscriptionPlan.yearly,
          status: 'active',
          startedAt: DateTime.now(),
          endsAt: DateTime.now().add(const Duration(days: 365)),
        ),
      );
      await controller.load();

      expect(controller.quote(SubscriptionPlan.monthly).credit, 0);
    });

    test('knows when the user is an admin', () async {
      await controller.load();
      expect(controller.isAdmin, isFalse);

      repository.admin = true;
      await controller.load();
      expect(controller.isAdmin, isTrue);
    });

    test('admins cannot subscribe', () async {
      repository.admin = true;
      await controller.load();

      final result = await controller.checkout(
        SubscriptionPlan.monthly,
        returnUrl,
      );

      expect(result.url, isNull);
      expect(repository.sessions, isEmpty);
    });

    test('a failed admin check keeps the admin flag', () async {
      repository.admin = true;
      await controller.load();

      repository.adminCheckFails = true;
      await Future.wait([controller.load(), controller.load()]);

      expect(controller.isAdmin, isTrue);
    });

    test('loading after dispose does not throw', () async {
      final pending = controller.load();
      controller.dispose();

      await expectLater(pending, completes);
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
