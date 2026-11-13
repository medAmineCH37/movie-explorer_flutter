import 'package:flutter/material.dart';

import '../../domain/models/subscription.dart';
import 'date_text.dart';
import 'subscription_history.dart';

class CurrentPlanCard extends StatelessWidget {
  const CurrentPlanCard({
    super.key,
    required this.subscription,
    required this.isBusy,
    required this.onCancel,
  });

  final Subscription? subscription;
  final bool isBusy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final current = subscription;
    final plan = current?.plan ?? SubscriptionPlan.free;

    final status = switch (current) {
      null => 'No active subscription',
      Subscription(isCancelled: true) =>
        'Cancelled · access until ${formatDate(current.endsAt)}',
      _ => 'Active · renews on ${formatDate(current.endsAt)}',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  plan.isPaid
                      ? Icons.workspace_premium
                      : Icons.workspace_premium_outlined,
                  color: plan.isPaid ? const Color(0xFFFFC857) : null,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT PLAN',
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.primary,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        plan.label,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(status, style: TextStyle(color: colors.onSurfaceVariant)),
            if (current != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  _Info(label: 'Started', value: formatDate(current.startedAt)),
                  _Info(label: 'Ends', value: formatDate(current.endsAt)),
                  _Info(label: 'Days left', value: '${current.daysLeft}'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                paymentSummary(current),
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              if (!current.isCancelled) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: isBusy ? null : onCancel,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel subscription'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
