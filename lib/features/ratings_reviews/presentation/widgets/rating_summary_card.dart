import 'package:flutter/material.dart';

import '../../domain/models/rating_summary.dart';
import 'star_rating.dart';

/// Community average, vote count and the 5→1 star distribution.
class RatingSummaryCard extends StatelessWidget {
  const RatingSummaryCard({super.key, required this.summary});

  final RatingSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 104,
              child: Column(
                children: [
                  Text(
                    summary.hasRatings
                        ? summary.average.toStringAsFixed(1)
                        : '–',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  StarRatingDisplay(value: summary.average, size: 16),
                  const SizedBox(height: 6),
                  Text(
                    summary.count == 1 ? '1 vote' : '${summary.count} votes',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  for (var score = 5; score >= 1; score--)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Semantics(
                        label: '$score stars: ${summary.votesFor(score)} votes',
                        excludeSemantics: true,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 14,
                              child: Text(
                                '$score',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                            const Icon(
                              Icons.star_rounded,
                              size: 12,
                              color: kStarColor,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(
                                    begin: 0,
                                    end: summary.barFraction(score),
                                  ),
                                  duration: const Duration(milliseconds: 450),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, value, _) =>
                                      LinearProgressIndicator(
                                        value: value,
                                        minHeight: 7,
                                        color: kStarColor,
                                        backgroundColor: theme
                                            .colorScheme
                                            .surfaceContainerHighest,
                                      ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 34,
                              child: Text(
                                '${summary.votesFor(score)}',
                                textAlign: TextAlign.end,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: muted,
                                ),
                              ),
                            ),
                          ],
                        ),
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
