import 'package:flutter/material.dart';

import '../../domain/models/review.dart';
import '../../domain/repositories/reviews_repository.dart';
import '../../domain/review_rules.dart';
import 'star_rating.dart';

/// Bottom sheet to write or edit a review, with optional AI drafting.
///
/// Returns the saved [Review], or `null` when dismissed.
Future<Review?> showReviewComposer(
  BuildContext context, {
  required ReviewsRepository repository,
  required int movieId,
  required String movieTitle,
  String? movieYear,
  int? myScore,
  Review? existing,
}) {
  return showModalBottomSheet<Review>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => ReviewComposer(
      repository: repository,
      movieId: movieId,
      movieTitle: movieTitle,
      movieYear: movieYear,
      myScore: myScore,
      existing: existing,
    ),
  );
}

class ReviewComposer extends StatefulWidget {
  const ReviewComposer({
    super.key,
    required this.repository,
    required this.movieId,
    required this.movieTitle,
    this.movieYear,
    this.myScore,
    this.existing,
  });

  final ReviewsRepository repository;
  final int movieId;
  final String movieTitle;
  final String? movieYear;
  final int? myScore;
  final Review? existing;

  @override
  State<ReviewComposer> createState() => _ReviewComposerState();
}

class _ReviewComposerState extends State<ReviewComposer> {
  late final TextEditingController _text;
  final TextEditingController _keywords = TextEditingController();
  late bool _spoiler;
  bool _saving = false;
  bool _drafting = false;
  bool _showAssistant = false;
  String? _error;
  String? _aiError;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.existing?.content ?? '')
      ..addListener(_refresh);
    _keywords.addListener(_refresh);
    _spoiler = widget.existing?.spoiler ?? false;
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _text.dispose();
    _keywords.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final error = ReviewRules.validateContent(_text.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = _isEdit
          ? await widget.repository.updateReview(
              widget.existing!.id,
              content: _text.text,
              spoiler: _spoiler,
            )
          : await widget.repository.createReview(
              widget.movieId,
              content: _text.text,
              spoiler: _spoiler,
            );
      if (mounted) Navigator.of(context).pop(saved);
    } on ReviewException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save your review.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _draft() async {
    final error = ReviewRules.validateAiKeywords(_keywords.text);
    if (error != null) {
      setState(() => _aiError = error);
      return;
    }
    if (_text.text.trim().isNotEmpty) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace your text?'),
          content: const Text(
            'The AI draft will replace what you have written so far.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (replace != true) return;
    }

    setState(() {
      _drafting = true;
      _aiError = null;
    });
    try {
      final draft = await widget.repository.draftReview(
        movieId: widget.movieId,
        movieTitle: widget.movieTitle,
        movieYear: widget.movieYear,
        keywords: _keywords.text,
      );
      if (!mounted) return;
      _text.value = TextEditingValue(
        text: draft,
        selection: TextSelection.collapsed(offset: draft.length),
      );
      setState(() => _showAssistant = false);
    } on ReviewException catch (e) {
      if (mounted) setState(() => _aiError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _aiError = 'The AI assistant is unavailable right now.');
      }
    } finally {
      if (mounted) setState(() => _drafting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final length = _text.text.trim().length;
    final valid = ReviewRules.validateContent(_text.text) == null;
    final busy = _saving || _drafting;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? 'Edit your review' : 'Write a review',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              [widget.movieTitle, ?widget.movieYear].join(' · '),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Your rating: ', style: theme.textTheme.bodyMedium),
                if (widget.myScore != null)
                  StarRatingDisplay(value: widget.myScore!.toDouble(), size: 16)
                else
                  Text(
                    'not rated (optional)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _text,
              enabled: !busy,
              minLines: 5,
              maxLines: 10,
              maxLength: ReviewRules.maxContentLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'What did you think of the movie?',
                errorText: _error,
                counterText:
                    '$length / ${ReviewRules.maxContentLength}'
                    '${length < ReviewRules.minContentLength ? '  ·  min ${ReviewRules.minContentLength}' : ''}',
              ),
            ),
            SwitchListTile(
              value: _spoiler,
              onChanged: busy ? null : (v) => setState(() => _spoiler = v),
              contentPadding: EdgeInsets.zero,
              title: const Text('Contains spoilers'),
              subtitle: const Text('Other viewers must tap to reveal it.'),
            ),
            _assistant(theme, busy),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: valid && !busy ? _save : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_isEdit ? Icons.check : Icons.send_outlined),
              label: Text(_isEdit ? 'Save changes' : 'Publish review'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _assistant(ThemeData theme, bool busy) {
    return Card(
      margin: EdgeInsets.zero,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: Icon(
                Icons.auto_awesome,
                color: theme.colorScheme.primary,
              ),
              title: const Text('Help me write it'),
              subtitle: const Text(
                'Give a few keywords, AI drafts the review.',
              ),
              trailing: Icon(
                _showAssistant ? Icons.expand_less : Icons.expand_more,
              ),
              onTap: busy
                  ? null
                  : () => setState(() => _showAssistant = !_showAssistant),
            ),
            if (_showAssistant)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _keywords,
                      enabled: !busy,
                      maxLength: ReviewRules.maxAiKeywordsLength,
                      decoration: InputDecoration(
                        hintText: 'stunning visuals, slow ending…',
                        errorText: _aiError,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: busy ? null : _draft,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: _drafting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(_drafting ? 'Writing…' : 'Draft my review'),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Uses your rating and keywords only. You can edit the '
                      'draft before publishing.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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
