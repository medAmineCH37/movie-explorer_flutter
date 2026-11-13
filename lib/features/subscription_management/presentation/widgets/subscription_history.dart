import 'package:flutter/material.dart';

import '../../domain/models/subscription.dart';
import 'date_text.dart';

String paymentSummary(Subscription subscription) {
  final parts = [
    subscription.amountPaid > 0
        ? 'Paid ${formatMoney(subscription.amountPaid)}'
        : subscription.creditApplied > 0
        ? 'Paid with credit'
        : 'No charge',
    if (subscription.creditApplied > 0)
      '${formatMoney(subscription.creditApplied)} credit used',
    if (subscription.refundAmount > 0)
      'Refunded ${formatMoney(subscription.refundAmount)}',
    ?subscription.card?.label,
  ];
  return parts.join(' · ');
}

/// Every subscription of the user (active, cancelled and expired), newest
/// first. Tapping one opens its details.
class SubscriptionHistory extends StatelessWidget {
  const SubscriptionHistory({super.key, required this.subscriptions});

  final List<Subscription> subscriptions;

  @override
  Widget build(BuildContext context) {
    if (subscriptions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No subscriptions yet.'),
      );
    }

    final sorted = [...subscriptions]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final subscription in sorted)
            ListTile(
              leading: Icon(_iconFor(subscription.state)),
              title: Text(subscription.plan.label),
              subtitle: Text(
                '${formatDate(subscription.startedAt)} → '
                '${formatDate(subscription.endsAt)}\n'
                '${paymentSummary(subscription)}',
              ),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SubscriptionStateChip(state: subscription.state),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () => showSubscriptionDetails(context, subscription),
            ),
        ],
      ),
    );
  }
}

IconData _iconFor(SubscriptionState state) => switch (state) {
  SubscriptionState.active => Icons.verified_outlined,
  SubscriptionState.cancelled => Icons.cancel_outlined,
  SubscriptionState.expired => Icons.history,
};

class SubscriptionStateChip extends StatelessWidget {
  const SubscriptionStateChip({super.key, required this.state});

  final SubscriptionState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, foreground) = switch (state) {
      SubscriptionState.active => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      SubscriptionState.cancelled => (
        colors.errorContainer,
        colors.onErrorContainer,
      ),
      SubscriptionState.expired => (
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        state.label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Bottom sheet with every detail of one subscription.
Future<void> showSubscriptionDetails(
  BuildContext context,
  Subscription subscription,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _SubscriptionDetails(subscription: subscription),
  );
}

class _SubscriptionDetails extends StatelessWidget {
  const _SubscriptionDetails({required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final s = subscription;
    final theme = Theme.of(context);
    final rows = <(String, String)>[
      ('Status', s.state.label),
      ('Price', s.plan.priceLabel),
      ('Duration', '${s.plan.durationDays} days'),
      ('Start date', formatDate(s.startedAt)),
      ('End date', formatDate(s.endsAt)),
      if (s.isActive) ('Days left', '${s.daysLeft}'),
      ('Amount paid', formatMoney(s.amountPaid)),
      if (s.creditApplied > 0) ('Credit used', formatMoney(s.creditApplied)),
      if (s.refundAmount > 0) ('Refunded', formatMoney(s.refundAmount)),
      ('Net paid', formatMoney(s.netPaid)),
      ('Payment method', s.card?.label ?? '—'),
      ('Reference', '#${s.id}'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.plan.label,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SubscriptionStateChip(state: s.state),
            ],
          ),
          if (s.plan.perks.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final perk in s.plan.perks)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(perk)),
                  ],
                ),
              ),
          ],
          const Divider(height: 28),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
