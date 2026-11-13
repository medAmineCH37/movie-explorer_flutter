import '../models/subscription.dart';

abstract class SubscriptionRepository {
  Future<List<Subscription>> getSubscriptions();

  Future<void> subscribe(SubscriptionPlan plan);

  Future<void> cancel(int subscriptionId);

  Future<bool> isAdmin();
}

abstract class AdminSubscriptionRepository {
  Future<bool> isAdmin();

  Future<List<Subscription>> getAllSubscriptions();

  Future<List<AppUser>> getUsers();

  Future<void> grant(String userId, SubscriptionPlan plan);

  Future<void> cancel(int subscriptionId);

  Future<void> endNow(int subscriptionId);

  Future<void> extend(Subscription subscription, int days);
}
