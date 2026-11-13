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

  String _now() => DateTime.now().toUtc().toIso8601String();

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
  Future<void> subscribe(SubscriptionPlan plan) => grant(_userId, plan);

  @override
  Future<void> cancel(int subscriptionId) async {
    await _client
        .from('subscriptions')
        .update({'status': 'cancelled'})
        .eq('id', subscriptionId);
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
  Future<void> endNow(int subscriptionId) async {
    await _client
        .from('subscriptions')
        .update({'status': 'cancelled', 'ends_at': _now()})
        .eq('id', subscriptionId);
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
