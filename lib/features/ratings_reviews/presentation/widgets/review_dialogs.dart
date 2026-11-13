import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/repositories/reviews_repository.dart';
import '../../domain/review_rules.dart';

/// Confirmation for destructive actions. Returns `true` when confirmed.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Shows [message] in a snackbar, with a sign-in action when needed.
void showReviewMessage(
  BuildContext context,
  String message, {
  bool requiresSignIn = false,
}) {
  final router = GoRouter.maybeOf(context);
  final location = router?.routeInformationProvider.value.uri.toString();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: requiresSignIn && router != null
            ? SnackBarAction(
                label: 'Sign in',
                onPressed: () => router.push(
                  '/login?redirect=${Uri.encodeComponent(location ?? '/')}',
                ),
              )
            : null,
      ),
    );
}

/// Runs [action] and reports a [ReviewException] (or any error) in a
/// snackbar. Returns `true` on success.
Future<bool> runReviewAction(
  BuildContext context,
  Future<void> Function() action, {
  String? successMessage,
}) async {
  try {
    await action();
    if (successMessage != null && context.mounted) {
      showReviewMessage(context, successMessage);
    }
    return true;
  } on ReviewException catch (e) {
    if (context.mounted) {
      showReviewMessage(context, e.message, requiresSignIn: e.requiresSignIn);
    }
  } catch (_) {
    if (context.mounted) {
      showReviewMessage(context, 'Something went wrong. Please try again.');
    }
  }
  return false;
}

/// Bottom sheet asking for a report reason. Returns `true` once
/// [onSubmit] succeeded.
Future<bool> showReportSheet(
  BuildContext context, {
  required Future<void> Function(String reason) onSubmit,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReportSheet(onSubmit: onSubmit),
  );
  return result ?? false;
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.onSubmit});

  final Future<void> Function(String reason) onSubmit;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final error = ReviewRules.validateReportReason(_controller.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_controller.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } on ReviewException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not send the report.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = ReviewRules.validateReportReason(_controller.text) == null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Report this review',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text('Tell us what is wrong. Moderators will look at it.'),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 4,
            minLines: 2,
            maxLength: ReviewRules.maxReportReasonLength,
            enabled: !_submitting,
            decoration: InputDecoration(
              hintText: 'Spam, insults, unmarked spoilers…',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: valid && !_submitting ? _submit : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.flag_outlined),
            label: const Text('Send report'),
          ),
        ],
      ),
    );
  }
}
