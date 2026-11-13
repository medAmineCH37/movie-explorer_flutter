import 'package:flutter/material.dart';

import '../../domain/models/subscription.dart';
import 'date_text.dart';
import 'subscription_history.dart';

enum AdminAction { extend, refund, revoke }

class AdminSubscriptionTile extends StatelessWidget {
  const AdminSubscriptionTile({
    super.key,
    required this.subscription,
    required this.isBusy,
    required this.onAction,
  });

  final Subscription subscription;
  final bool isBusy;
  final void Function(AdminAction action) onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final state = subscription.state;
    final stateColor = switch (state) {
      SubscriptionState.active => Colors.greenAccent,
      SubscriptionState.cancelled => Colors.orangeAccent,
      SubscriptionState.expired => colors.onSurfaceVariant,
    };

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        leading: CircleAvatar(
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
          child: Text(
            (subscription.userName ?? '?').characters.first.toUpperCase(),
          ),
        ),
        title: Text(
          subscription.userName ?? 'Unknown user',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subscription.plan.label),
            Text(paymentSummary(subscription)),
            Text(
              '${formatDate(subscription.startedAt)} → '
              '${formatDate(subscription.endsAt)}',
            ),
            Text(
              state == SubscriptionState.active
                  ? '${state.label} · ${subscription.daysLeft} days left'
                  : state.label,
              style: TextStyle(color: stateColor, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: state == SubscriptionState.cancelled
            ? null
            : PopupMenuButton<AdminAction>(
                enabled: !isBusy,
                tooltip: 'Manage',
                onSelected: onAction,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: AdminAction.extend,
                    child: ListTile(
                      leading: Icon(Icons.more_time),
                      title: Text('Extend 30 days'),
                    ),
                  ),
                  if (state == SubscriptionState.active) ...[
                    PopupMenuItem(
                      value: AdminAction.refund,
                      child: ListTile(
                        leading: const Icon(Icons.currency_exchange),
                        title: Text(
                          'Cancel and refund '
                          '(${formatMoney(subscription.unusedValue)})',
                        ),
                      ),
                    ),
                    const PopupMenuItem(
                      value: AdminAction.revoke,
                      child: ListTile(
                        leading: Icon(Icons.block),
                        title: Text('Revoke access (no refund)'),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
