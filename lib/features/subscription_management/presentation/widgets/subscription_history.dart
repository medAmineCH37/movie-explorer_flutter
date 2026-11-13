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

class SubscriptionHistory extends StatelessWidget {
  const SubscriptionHistory({super.key, required this.subscriptions});

  final List<Subscription> subscriptions;

  @override
  Widget build(BuildContext context) {
    if (subscriptions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No past subscriptions.'),
      );
    }

    return Card(
      child: Column(
        children: [
          for (final subscription in subscriptions)
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(subscription.plan.label),
              subtitle: Text(
                '${formatDate(subscription.startedAt)} → '
                '${formatDate(subscription.endsAt)}\n'
                '${paymentSummary(subscription)}',
              ),
              isThreeLine: true,
              trailing: Text(
                subscription.isCancelled ? 'Cancelled' : 'Expired',
              ),
            ),
        ],
      ),
    );
  }
}
