import 'package:flutter/material.dart';

import '../../domain/models/ai_review_summary.dart';
import '../../domain/repositories/reviews_repository.dart';
import '../../domain/review_rules.dart';

/// On-demand AI digest of the reviews. Hidden below
/// [ReviewRules.minReviewsForSummary] reviews.
class AiReviewSummaryCard extends StatefulWidget {
  const AiReviewSummaryCard({
    super.key,
    required this.repository,
    required this.movieId,
    required this.reviewCount,
  });

  final ReviewsRepository repository;
  final int movieId;
  final int reviewCount;

  @override
  State<AiReviewSummaryCard> createState() => _AiReviewSummaryCardState();
}

class _AiReviewSummaryCardState extends State<AiReviewSummaryCard> {
  AiReviewSummary? _summary;
  bool _loading = false;
  String? _error;

  @override
  void didUpdateWidget(AiReviewSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new or deleted review makes the shown summary stale.
    if (oldWidget.reviewCount != widget.reviewCount) _summary = null;
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await widget.repository.getAiSummary(widget.movieId);
      if (mounted) setState(() => _summary = summary);
    } on ReviewException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'The AI assistant is unavailable right now.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reviewCount < ReviewRules.minReviewsForSummary) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final summary = _summary;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.18),
            const Color(0xFF1B1B23),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        alignment: Alignment.topCenter,
        child: summary == null ? _prompt(theme) : _result(theme, summary),
      ),
    );
  }

  Widget _prompt(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'What do viewers think?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Get a short AI summary of the ${widget.reviewCount} reviews.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: _loading ? null : _generate,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(
            _loading
                ? 'Analysing reviews…'
                : _error != null
                ? 'Try again'
                : 'Summarize reviews with AI',
          ),
        ),
      ],
    );
  }

  Widget _result(ThemeData theme, AiReviewSummary summary) {
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'What viewers think',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          summary.summary,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
        if (summary.strengths.isNotEmpty) ...[
          const SizedBox(height: 12),
          _PointList(
            icon: Icons.thumb_up_alt_outlined,
            color: Colors.greenAccent,
            title: 'Strengths',
            points: summary.strengths,
          ),
        ],
        if (summary.weaknesses.isNotEmpty) ...[
          const SizedBox(height: 10),
          _PointList(
            icon: Icons.thumb_down_alt_outlined,
            color: Colors.orangeAccent,
            title: 'Weaknesses',
            points: summary.weaknesses,
          ),
        ],
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 14, color: muted?.color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'AI-generated (Gemini) from ${summary.reviewCount} published '
                'reviews, spoiler reviews excluded. It may be inaccurate.',
                style: muted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PointList extends StatelessWidget {
  const _PointList({
    required this.icon,
    required this.color,
    required this.title,
    required this.points,
  });

  final IconData icon;
  final Color color;
  final String title;
  final List<String> points;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final point in points)
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 2),
            child: Text('• $point'),
          ),
      ],
    );
  }
}
