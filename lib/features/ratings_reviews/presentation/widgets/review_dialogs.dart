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
