import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/subscription.dart';
import '../domain/repositories/subscription_repository.dart';

class SubscriptionService implements SubscriptionRepository {
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

  @override
  Future<void> subscribe(SubscriptionPlan plan) async {
    final now = DateTime.now().toUtc();

    await _client
        .from('subscriptions')
        .update({'status': 'cancelled', 'ends_at': now.toIso8601String()})
        .eq('user_id', _userId)
        .gt('ends_at', now.toIso8601String());

    await _client.from('subscriptions').insert({
      'user_id': _userId,
      'plan': plan.value,
      'started_at': now.toIso8601String(),
      'ends_at': now.add(Duration(days: plan.durationDays)).toIso8601String(),
    });
  }

  @override
  Future<void> cancel(int subscriptionId) async {
    await _client
        .from('subscriptions')
        .update({'status': 'cancelled'})
        .eq('user_id', _userId)
        .eq('id', subscriptionId);
  }
}
