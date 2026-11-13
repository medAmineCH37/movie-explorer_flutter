import 'package:flutter/material.dart';

import '../../domain/review_rules.dart';

const Color kStarColor = Color(0xFFFFC857);

/// Read-only stars with half-star precision (e.g. 3.6 → ★★★½☆).
class StarRatingDisplay extends StatelessWidget {
  const StarRatingDisplay({super.key, required this.value, this.size = 18});

  final double value;
  final double size;

  /// Rounds to the nearest half star.
  static double roundToHalf(double value) =>
      (value * 2).round().clamp(0, 10) / 2;

  @override
  Widget build(BuildContext context) {
    final rounded = roundToHalf(value);
    final empty = Theme.of(context).colorScheme.outline;
    return Semantics(
      label: '${value.toStringAsFixed(1)} out of 5 stars',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              rounded >= i
                  ? Icons.star_rounded
                  : rounded >= i - 0.5
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded,
              size: size,
              color: rounded >= i - 0.5 ? kStarColor : empty,
            ),
        ],
      ),
    );
  }
}

/// Tappable 1–5 star picker with the label of the selected score.
class StarRatingInput extends StatelessWidget {
  const StarRatingInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.size = 36,
    this.showLabel = true,
  });

  final int? value;
  final ValueChanged<int>? onChanged;
  final bool enabled;
  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = ReviewRules.scoreLabel(value);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var score = 1; score <= 5; score++)
          Semantics(
            button: true,
            selected: value == score,
            label:
                '$score star${score == 1 ? '' : 's'}, '
                '${ReviewRules.scoreLabel(score)}',
            excludeSemantics: true,
            child: InkResponse(
              onTap: enabled && onChanged != null
                  ? () => onChanged!(score)
                  : null,
              radius: size * 0.7,
              child: Padding(
                // Keeps each star at least 48px wide for touch.
                padding: EdgeInsets.all(((48 - size) / 2).clamp(4, 16)),
                child: AnimatedScale(
                  scale: (value ?? 0) >= score ? 1.0 : 0.9,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    (value ?? 0) >= score
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: size,
                    color: (value ?? 0) >= score
                        ? kStarColor
                        : theme.colorScheme.outline,
                  ),
                ),
              ),
            ),
          ),
        if (showLabel) ...[
          const SizedBox(width: 8),
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                label ?? '',
                key: ValueKey(label),
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: kStarColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
