import 'package:flutter/material.dart';

class AdminStats extends StatelessWidget {
  const AdminStats({
    super.key,
    required this.active,
    required this.monthly,
    required this.yearly,
    required this.revenue,
  });

  final int active;
  final int monthly;
  final int yearly;
  final double revenue;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.2,
      children: [
        _StatCard(
          label: 'Active subscribers',
          value: '$active',
          icon: Icons.people_outline,
        ),
        _StatCard(
          label: 'Total revenue',
          value: '${revenue.toStringAsFixed(2)} TND',
          icon: Icons.payments_outlined,
        ),
        _StatCard(
          label: 'Monthly plans',
          value: '$monthly',
          icon: Icons.calendar_view_month,
        ),
        _StatCard(
          label: 'Yearly plans',
          value: '$yearly',
          icon: Icons.calendar_today_outlined,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: colors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
