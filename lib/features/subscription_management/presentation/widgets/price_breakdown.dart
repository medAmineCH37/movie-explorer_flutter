import 'package:flutter/material.dart';

import '../../domain/models/subscription.dart';

class PriceBreakdown extends StatelessWidget {
  const PriceBreakdown({super.key, required this.change});

  final PlanChange change;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final from = change.from;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _Line(
            label: change.plan.label,
            value: formatMoney(change.plan.price),
          ),
          if (from != null && change.credit > 0)
            _Line(
              label:
                  'Credit: ${from.unusedDays} unused days of ${from.plan.label}',
              value: '− ${formatMoney(change.credit)}',
              color: Colors.greenAccent,
            ),
          const Divider(height: 20),
          _Line(
            label: 'Total due today',
            value: formatMoney(change.total),
            bold: true,
          ),
          if (change.refund > 0)
            _Line(
              label: 'Refund to your card',
              value: formatMoney(change.refund),
              color: Colors.greenAccent,
              bold: true,
            ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.color,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: color,
      fontWeight: bold ? FontWeight.bold : null,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Text(value, style: style),
        ],
      ),
    );
  }
}
