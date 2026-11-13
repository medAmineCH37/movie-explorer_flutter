import 'package:flutter/material.dart';

Future<void> showReportReviewDialog(BuildContext context) async {
  const reasons = [
    'Dangerous',
    'Inappropriate',
    'Not good / low quality',
    'Spam',
    'Other',
  ];
  final selected = <String>{};
  final controller = TextEditingController();

  final submitted = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Report review'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Why are you reporting this review?'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final reason in reasons)
                    FilterChip(
                      label: Text(reason),
                      selected: selected.contains(reason),
                      onSelected: (value) => setState(() {
                        if (value) {
                          selected.add(reason);
                        } else {
                          selected.remove(reason);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 3,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Tell us more (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            // Disabled until at least one reason is ticked.
            onPressed: selected.isEmpty ? null : () => Navigator.pop(ctx, true),
            child: const Text('Report'),
          ),
        ],
      ),
    ),
  );

  if (submitted == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Review reported')),
    );
  }
}