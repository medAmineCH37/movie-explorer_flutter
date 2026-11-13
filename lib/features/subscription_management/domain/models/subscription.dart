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
  final String? userId;
  final String? userName;

  bool get isCancelled => status == 'cancelled';

  bool get isActive => endsAt.isAfter(DateTime.now());

  SubscriptionState get state => !isActive
      ? SubscriptionState.expired
      : isCancelled
      ? SubscriptionState.cancelled
      : SubscriptionState.active;

  int get daysLeft {
    if (!isActive) return 0;
    return (endsAt.difference(DateTime.now()).inHours / 24).ceil();
  }
}
