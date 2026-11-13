enum SubscriptionPlan {
  free('free', 'Free', 0, 0, [
    'Browse and search movies',
    'Favorites and watchlist',
  ]),
  monthly('monthly', 'Premium Monthly', 9.99, 30, [
    'Everything in Free',
    'Unlimited collections',
    'Ad-free experience',
  ]),
  yearly('yearly', 'Premium Yearly', 99.99, 365, [
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
    SubscriptionPlan.monthly => '${price.toStringAsFixed(2)} TND / month',
    SubscriptionPlan.yearly => '${price.toStringAsFixed(2)} TND / year',
  };

  static SubscriptionPlan fromValue(Object? value) =>
      SubscriptionPlan.values.firstWhere(
        (plan) => plan.value == value,
        orElse: () => SubscriptionPlan.free,
      );
}

class Subscription {
  const Subscription({
    required this.id,
    required this.plan,
    required this.status,
    required this.startedAt,
    required this.endsAt,
  });

  factory Subscription.fromMap(Map<String, dynamic> map) => Subscription(
    id: map['id'] as int,
    plan: SubscriptionPlan.fromValue(map['plan']),
    status: map['status'] as String,
    startedAt: DateTime.parse(map['started_at'] as String).toLocal(),
    endsAt: DateTime.parse(map['ends_at'] as String).toLocal(),
  );

  final int id;
  final SubscriptionPlan plan;
  final String status;
  final DateTime startedAt;
  final DateTime endsAt;

  bool get isCancelled => status == 'cancelled';

  bool get isActive => endsAt.isAfter(DateTime.now());

  int get daysLeft {
    if (!isActive) return 0;
    return (endsAt.difference(DateTime.now()).inHours / 24).ceil();
  }
}
