import '../models/subscription.dart';

abstract class SubscriptionRepository {
  Future<List<Subscription>> getSubscriptions();

  Future<CheckoutResult> checkout(SubscriptionPlan plan, String returnUrl);

  Future<void> confirmCheckout(String sessionId);

  Future<double> cancelWithRefund();

  Future<bool> isAdmin();
}

abstract class AdminSubscriptionRepository {
  Future<bool> isAdmin();

  Future<List<Subscription>> getAllSubscriptions();

  Future<List<AppUser>> getUsers();

  Future<void> grant(String userId, SubscriptionPlan plan);

  Future<double> endSubscription(int subscriptionId, {required bool refund});

  Future<void> extend(Subscription subscription, int days);
}
