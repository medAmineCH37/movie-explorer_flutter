import 'package:flutter/material.dart';

import '../../domain/models/subscription.dart';
import 'date_text.dart';

enum AdminAction { extend, cancel, endNow }

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
            Text(
              '${formatDate(subscription.startedAt)} → '
              '${formatDate(subscription.endsAt)}',
            ),
            Text(
              state == SubscriptionState.expired
                  ? state.label
                  : '${state.label} · ${subscription.daysLeft} days left',
              style: TextStyle(color: stateColor, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<AdminAction>(
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
            if (state == SubscriptionState.active)
              const PopupMenuItem(
                value: AdminAction.cancel,
                child: ListTile(
                  leading: Icon(Icons.cancel_outlined),
                  title: Text('Cancel at period end'),
                ),
              ),
            if (state != SubscriptionState.expired)
              const PopupMenuItem(
                value: AdminAction.endNow,
                child: ListTile(
                  leading: Icon(Icons.block),
                  title: Text('End now'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
