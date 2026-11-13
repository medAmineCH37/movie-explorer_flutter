import 'dart:math';

enum SubscriptionPlan {
  free('free', 'Free', 0, 0, [
    'Browse and search movies',
    'Favorites and watchlist',
  ]),
  monthly('monthly', 'Premium Monthly', 2.99, 30, [
    'Everything in Free',
    'Unlimited collections',
    'Ad-free experience',
  ]),
  yearly('yearly', 'Premium Yearly', 29.99, 365, [
    'Everything in Monthly',
    'Two months free',
    'Early access to new features',
  ]);

  const SubscriptionPlan(
    this.value,
    this.label,
    this.price,
    this.durationDays,
    this.perks,
  );

  final String value;
  final String label;
  final double price;
  final int durationDays;
  final List<String> perks;

  bool get isPaid => this != SubscriptionPlan.free;

  String get priceLabel => switch (this) {
    SubscriptionPlan.free => 'Free',
    SubscriptionPlan.monthly => '${formatMoney(price)} / month',
    SubscriptionPlan.yearly => '${formatMoney(price)} / year',
  };

  static SubscriptionPlan fromValue(Object? value) =>
      SubscriptionPlan.values.firstWhere(
        (plan) => plan.value == value,
        orElse: () => SubscriptionPlan.free,
      );
}

enum SubscriptionState {
  active('Active'),
  cancelled('Cancelled'),
  expired('Expired');

  const SubscriptionState(this.label);

  final String label;
}

class AppUser {
  const AppUser({required this.id, required this.name});

  factory AppUser.fromMap(Map<String, dynamic> map) {
    final name = (map['display_name'] as String?)?.trim();
    return AppUser(
      id: map['id'] as String,
      name: name == null || name.isEmpty
          ? (map['username'] as String?) ?? 'Unnamed user'
          : name,
    );
  }

  final String id;
  final String name;
}

class Subscription {
  const Subscription({
    required this.id,
    required this.plan,
    required this.status,
    required this.startedAt,
    required this.endsAt,
    this.amountPaid = 0,
    this.refundAmount = 0,
    this.creditApplied = 0,
    this.cardBrand,
    this.cardLast4,
    this.userId,
    this.userName,
  });

  factory Subscription.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    final name = (profile?['display_name'] as String?)?.trim();

    return Subscription(
      id: map['id'] as int,
      plan: SubscriptionPlan.fromValue(map['plan']),
      status: map['status'] as String,
      startedAt: DateTime.parse(map['started_at'] as String).toLocal(),
      endsAt: DateTime.parse(map['ends_at'] as String).toLocal(),
      amountPaid: (map['amount_paid'] as num?)?.toDouble() ?? 0,
      refundAmount: (map['refund_amount'] as num?)?.toDouble() ?? 0,
      creditApplied: (map['credit_applied'] as num?)?.toDouble() ?? 0,
      cardBrand: map['card_brand'] as String?,
      cardLast4: map['card_last4'] as String?,
      userId: map['user_id'] as String?,
      userName: name == null || name.isEmpty
          ? (profile?['username'] as String?)
          : name,
    );
  }

  final int id;
  final SubscriptionPlan plan;
  final String status;
  final DateTime startedAt;
  final DateTime endsAt;
  final double amountPaid;
  final double refundAmount;
  final double creditApplied;
  final String? cardBrand;
  final String? cardLast4;
  final String? userId;
  final String? userName;

  bool get isCancelled => status == 'cancelled';

  bool get isActive => !isCancelled && endsAt.isAfter(DateTime.now());

  SubscriptionState get state => isCancelled
      ? SubscriptionState.cancelled
      : isActive
      ? SubscriptionState.active
      : SubscriptionState.expired;

  int get daysLeft {
    if (!isActive) return 0;
    return (endsAt.difference(DateTime.now()).inHours / 24).ceil();
  }

  int get unusedDays {
    if (!isActive) return 0;
    return min(endsAt.difference(DateTime.now()).inDays, plan.durationDays);
  }

  int get usedDays => plan.durationDays - unusedDays;

  double get unusedValue {
    final value = plan.price * unusedDays / plan.durationDays;
    return roundMoney(
      max(0, min(value, amountPaid + creditApplied - refundAmount)),
    );
  }

  double get netPaid => roundMoney(amountPaid - refundAmount);

  PaymentCard? get card => cardBrand == null || cardLast4 == null
      ? null
      : PaymentCard(brand: cardBrand!, last4: cardLast4!);
}

class PaymentCard {
  const PaymentCard({required this.brand, required this.last4});

  final String brand;
  final String last4;

  String get label => '$brand •••• $last4';
}

class PlanChange {
  const PlanChange({required this.plan, this.from, this.credit = 0});

  factory PlanChange.to(SubscriptionPlan plan, Subscription? current) =>
      PlanChange(plan: plan, from: current, credit: current?.unusedValue ?? 0);

  final SubscriptionPlan plan;
  final Subscription? from;
  final double credit;

  double get total {
    final value = roundMoney(max(0, plan.price - credit));
    return value > 0 && value < minimumCharge ? minimumCharge : value;
  }

  double get refund => roundMoney(max(0, credit - plan.price));

  bool get isUpgrade => from != null && plan.price > from!.plan.price;

  bool get isDowngrade => from != null && plan.price < from!.plan.price;
}

const minimumCharge = 0.5;

class CheckoutResult {
  const CheckoutResult({this.url, this.refund = 0});

  final String? url;
  final double refund;
}

double roundMoney(double value) => (value * 100).round() / 100;

String formatMoney(double value) => '${value.toStringAsFixed(2)} €';
