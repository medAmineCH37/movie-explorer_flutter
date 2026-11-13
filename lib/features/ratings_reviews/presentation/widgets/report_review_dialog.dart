import 'package:flutter/material.dart';

import '../../domain/repositories/reviews_repository.dart';
import '../../domain/review_rules.dart';

/// Report dialog: pick one or more reasons, optionally add details.
///
/// The reasons and details are sent through [onSubmit] (stored in
/// `review_reports`). Returns `true` once the report was saved.
Future<bool> showReportReviewDialog(
  BuildContext context, {
  required Future<void> Function(String reason) onSubmit,
}) async {
  final sent = await showDialog<bool>(
    context: context,
    builder: (_) => _ReportReviewDialog(onSubmit: onSubmit),
  );
  return sent ?? false;
}

class _ReportReviewDialog extends StatefulWidget {
  const _ReportReviewDialog({required this.onSubmit});

  final Future<void> Function(String reason) onSubmit;

  static const reasons = [
    'Dangerous',
    'Inappropriate',
    'Not good / low quality',
    'Spam',
    'Other',
  ];

  @override
  State<_ReportReviewDialog> createState() => _ReportReviewDialogState();
}

class _ReportReviewDialogState extends State<_ReportReviewDialog> {
  final Set<String> _selected = {};
  final TextEditingController _details = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  /// "Spam, Inappropriate: details…", kept within the 300-character limit.
  String _reason() {
    final reasons = _ReportReviewDialog.reasons
        .where(_selected.contains)
        .join(', ');
    final details = _details.text.trim();
    final text = details.isEmpty ? reasons : '$reasons: $details';
    return text.length <= ReviewRules.maxReportReasonLength
        ? text
        : text.substring(0, ReviewRules.maxReportReasonLength).trimRight();
  }

  Future<void> _submit() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_reason());
      if (mounted) Navigator.of(context).pop(true);
    } on ReviewException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not send the report.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The longest reason prefix plus details must fit in 300 characters.
    final maxDetails =
        ReviewRules.maxReportReasonLength -
        _ReportReviewDialog.reasons.join(', ').length -
        2;

    return AlertDialog(
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
                for (final reason in _ReportReviewDialog.reasons)
                  FilterChip(
                    label: Text(reason),
                    selected: _selected.contains(reason),
                    onSelected: _sending
                        ? null
                        : (value) => setState(() {
                            value
                                ? _selected.add(reason)
                                : _selected.remove(reason);
                          }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _details,
              enabled: !_sending,
              maxLines: 3,
              maxLength: maxDetails,
              decoration: InputDecoration(
                labelText: 'Tell us more (optional)',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          // Disabled until at least one reason is ticked.
          onPressed: _selected.isEmpty || _sending ? null : _submit,
          child: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Report'),
        ),
      ],
    );
  }
}
