import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/repositories/movies_repository.dart';

/// Shared create/edit/delete entry points for the movie screens.
abstract final class MovieActions {
  /// Opens the create form, or the edit form when [movieId] is given.
  /// Returns `true` when a movie was saved.
  static Future<bool> openEditor(
    BuildContext context,
    MoviesRepository repository, {
    int? movieId,
  }) async {
    if (!repository.canEdit) {
      showMessage(context, 'Sign in to manage movies.', requiresSignIn: true);
      return false;
    }
    final saved = await context.push<bool>(
      movieId == null ? '/movies/new' : '/movie/$movieId/edit',
    );
    return saved ?? false;
  }

  /// Confirms, deletes and reports. Returns `true` when deleted.
  static Future<bool> delete(
    BuildContext context,
    MoviesRepository repository, {
    required int movieId,
    required String title,
  }) async {
    if (!repository.canEdit) {
      showMessage(context, 'Sign in to manage movies.', requiresSignIn: true);
      return false;
    }
    final colors = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this movie?'),
        content: Text(
          '"$title" will be removed from the catalogue for everyone. '
          'Its ratings and reviews are kept but shown as removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return false;

    try {
      await repository.deleteMovie(movieId);
      if (context.mounted) showMessage(context, '"$title" deleted.');
      return true;
    } on MovieException catch (e) {
      if (context.mounted) {
        showMessage(context, e.message, requiresSignIn: e.requiresSignIn);
      }
    } catch (_) {
      if (context.mounted) {
        showMessage(context, 'Could not delete the movie. Try again.');
      }
    }
    return false;
  }

  static void showMessage(
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
}
