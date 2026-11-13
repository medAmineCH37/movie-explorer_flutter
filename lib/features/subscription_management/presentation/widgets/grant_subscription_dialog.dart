import 'package:flutter/material.dart';

import '../../domain/models/subscription.dart';

class GrantSubscriptionResult {
  const GrantSubscriptionResult(this.userId, this.plan);

  final String userId;
  final SubscriptionPlan plan;
}

class GrantSubscriptionDialog extends StatefulWidget {
  const GrantSubscriptionDialog({super.key, required this.users});

  final List<AppUser> users;

  @override
  State<GrantSubscriptionDialog> createState() =>
      _GrantSubscriptionDialogState();
}

class _GrantSubscriptionDialogState extends State<GrantSubscriptionDialog> {
  String? _userId;
  SubscriptionPlan _plan = SubscriptionPlan.monthly;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Grant a subscription'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _userId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'User'),
            items: [
              for (final user in widget.users)
                DropdownMenuItem(value: user.id, child: Text(user.name)),
            ],
            onChanged: (value) => setState(() => _userId = value),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<SubscriptionPlan>(
            initialValue: _plan,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Plan'),
            items: [
              for (final plan in SubscriptionPlan.values.where((p) => p.isPaid))
                DropdownMenuItem(value: plan, child: Text(plan.label)),
            ],
            onChanged: (value) => setState(() => _plan = value ?? _plan),
          ),
          const SizedBox(height: 12),
          const Text(
            'Any active subscription of this user will be replaced.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _userId == null
              ? null
              : () =>
                    Navigator.of(context)
                        .pop(GrantSubscriptionResult(_userId!, _plan)),
          child: const Text('Grant'),
        ),
      ],
    );
  }
}
