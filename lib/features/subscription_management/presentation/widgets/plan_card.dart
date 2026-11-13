import 'package:flutter/material.dart';

import '../../domain/models/subscription.dart';

class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.plan,
    required this.currentPlan,
    required this.change,
    required this.isBusy,
    required this.onSubscribe,
  });

  final SubscriptionPlan plan;
  final SubscriptionPlan currentPlan;
  final PlanChange change;
  final bool isBusy;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isCurrent = plan == currentPlan;

    return Card(
      shape: isCurrent
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: colors.primary, width: 2),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.label,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (plan == SubscriptionPlan.yearly)
                  Chip(
                    label: const Text('Best value'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: colors.primaryContainer,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              plan.priceLabel,
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            for (final perk in plan.perks)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 18, color: colors.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(perk)),
                  ],
                ),
              ),
            if (plan.isPaid && !isCurrent && change.credit > 0) ...[
              const SizedBox(height: 6),
              Text(
                change.refund > 0
                    ? 'Nothing to pay today · ${formatMoney(change.refund)} refunded'
                    : 'Due today: ${formatMoney(change.total)} '
                          '(${formatMoney(change.credit)} credit applied)',
                style: TextStyle(color: colors.secondary),
              ),
            ],
            if (plan.isPaid) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isCurrent || isBusy ? null : onSubscribe,
                  child: Text(
                    isCurrent
                        ? 'Current plan'
                        : change.isUpgrade
                        ? 'Upgrade'
                        : change.isDowngrade
                        ? 'Downgrade'
                        : 'Subscribe',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
