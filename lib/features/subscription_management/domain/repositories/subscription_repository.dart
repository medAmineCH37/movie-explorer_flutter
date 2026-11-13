import '../models/subscription.dart';

abstract class SubscriptionRepository {
  Future<List<Subscription>> getSubscriptions();

  Future<void> subscribe(SubscriptionPlan plan);

  Future<void> cancel(int subscriptionId);
}
