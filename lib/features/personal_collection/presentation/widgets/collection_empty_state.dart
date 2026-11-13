import 'package:flutter/material.dart';

class CollectionEmptyState extends StatelessWidget {
  const CollectionEmptyState({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.buttonLabel,
    this.onAction,
  });

  final String title;
  final String description;
  final IconData icon;
  final String? buttonLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: colors.primary),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Colors.white60, height: 1.5),
            ),
            if (buttonLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.explore_outlined),
                label: Text(buttonLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
