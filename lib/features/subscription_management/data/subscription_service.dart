import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/subscription.dart';
import '../domain/repositories/subscription_repository.dart';

class SubscriptionService
    implements SubscriptionRepository, AdminSubscriptionRepository {
  SubscriptionService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('User must be authenticated.');
    }

    return user.id;
  }

  @override
  Future<List<Subscription>> getSubscriptions() async {
    final response = await _client
        .from('subscriptions')
        .select()
        .eq('user_id', _userId)
        .order('started_at', ascending: false);

    return response.map(Subscription.fromMap).toList();
  }

  Future<Map<String, dynamic>> _payments(Map<String, dynamic> body) async {
    try {
      final response = await _client.functions.invoke(
        'stripe-subscription',
        body: body,
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on FunctionException catch (e) {
      final details = e.details;
      throw Exception(
        details is Map && details['error'] != null
            ? details['error']
            : 'Payment service unavailable.',
      );
    }
  }

  @override
  Future<CheckoutResult> checkout(
    SubscriptionPlan plan,
    String returnUrl,
  ) async {
    final data = await _payments({
      'action': 'checkout',
      'plan': plan.value,
      'returnUrl': returnUrl,
    });
    return CheckoutResult(
      url: data['url'] as String?,
      refund: (data['refund'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  Future<void> confirmCheckout(String sessionId) async {
    await _payments({'action': 'confirm', 'sessionId': sessionId});
  }

  @override
  Future<double> cancelWithRefund() async {
    final data = await _payments({'action': 'cancel'});
    return (data['refund'] as num?)?.toDouble() ?? 0;
  }

  @override
  Future<bool> isAdmin() async {
    final response = await _client
        .from('profiles')
        .select('role')
        .eq('id', _userId)
        .maybeSingle();

    return response?['role'] == 'admin';
  }

  @override
  Future<List<Subscription>> getAllSubscriptions() async {
    final response = await _client
        .from('subscriptions')
        .select('*, profiles(display_name, username)')
        .order('started_at', ascending: false);

    return response.map(Subscription.fromMap).toList();
  }

  @override
  Future<List<AppUser>> getUsers() async {
    final response = await _client
        .from('profiles')
        .select('id, display_name, username')
        .order('display_name');

    return response.map(AppUser.fromMap).toList();
  }

  @override
  Future<void> grant(String userId, SubscriptionPlan plan) async {
    final now = DateTime.now().toUtc();

    await _client
        .from('subscriptions')
        .update({'status': 'cancelled', 'ends_at': now.toIso8601String()})
        .eq('user_id', userId)
        .gt('ends_at', now.toIso8601String());

    await _client.from('subscriptions').insert({
      'user_id': userId,
      'plan': plan.value,
      'started_at': now.toIso8601String(),
      'ends_at': now.add(Duration(days: plan.durationDays)).toIso8601String(),
    });
  }

  @override
  Future<double> endSubscription(
    int subscriptionId, {
    required bool refund,
  }) async {
    final data = await _payments({
      'action': 'admin_cancel',
      'subscriptionId': subscriptionId,
      'refund': refund,
    });
    return (data['refund'] as num?)?.toDouble() ?? 0;
  }

  @override
  Future<void> extend(Subscription subscription, int days) async {
    final now = DateTime.now();
    final base = subscription.endsAt.isAfter(now) ? subscription.endsAt : now;

    await _client
        .from('subscriptions')
        .update({
          'ends_at': base.add(Duration(days: days)).toUtc().toIso8601String(),
        })
        .eq('id', subscription.id);
  }
}
