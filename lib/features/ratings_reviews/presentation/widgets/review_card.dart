import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/models/review.dart';
import '../../domain/review_rules.dart';
import '../relative_time.dart';
import 'star_rating.dart';
import 'report_review_dialog.dart';

enum ReviewBadge { mine, mostLiked }

/// One review with author, score, date, spoiler protection, "read more"
/// and the actions allowed for the viewer.
class ReviewCard extends StatefulWidget {
  const ReviewCard({
    super.key,
    required this.review,
    required this.isSignedIn,
    this.isAdmin = false,
    this.badge,
    this.onLike,
    this.onEdit,
    this.onDelete,
    this.onReport,
  });

  final Review review;
  final bool isSignedIn;
  final bool isAdmin;
  final ReviewBadge? badge;
  final Future<void> Function()? onLike;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  bool _spoilerRevealed = false;
  bool _expanded = false;
  bool _liking = false;

  Review get _review => widget.review;

  bool get _canEdit => _review.isMine && widget.onEdit != null;
  bool get _canDelete =>
      (_review.isMine || widget.isAdmin) && widget.onDelete != null;
  bool get _canReport => widget.isSignedIn && !_review.isMine;

  Future<void> _like() async {
    if (_liking || widget.onLike == null) return;
    setState(() => _liking = true);
    try {
      await widget.onLike!();
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final highlighted = widget.badge != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B23),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlighted
              ? (widget.badge == ReviewBadge.mostLiked
                    ? kStarColor.withValues(alpha: 0.6)
                    : colors.primary.withValues(alpha: 0.7))
              : const Color(0xFF30303A),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.badge != null) ...[
            _Badge(badge: widget.badge!),
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(review: _review),
              const SizedBox(width: 12),
              Expanded(child: _AuthorLine(review: _review)),
              if (_canEdit || _canDelete || _canReport) _menu(),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _review.spoiler && !_spoilerRevealed
                ? _SpoilerCover(
                    onReveal: () => setState(() => _spoilerRevealed = true),
                  )
                : _content(theme),
          ),
          const SizedBox(height: 4),
          _likeRow(theme),
        ],
      ),
    );
  }

  Widget _content(ThemeData theme) {
    final text = _review.content;
    final isLong = text.length > ReviewRules.truncateAt;
    final shown = isLong && !_expanded
        ? '${text.substring(0, ReviewRules.truncateAt).trimRight()}…'
        : text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_review.spoiler)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Contains spoilers',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: Text(
            shown,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ),
        if (isLong)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(48, 40),
            ),
            child: Text(_expanded ? 'Show less' : 'Read more'),
          ),
          if (_review.spoiler)
            TextButton.icon(
              onPressed: () => setState(() => _spoilerRevealed = false),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              icon: const Icon(Icons.visibility_off_outlined, size: 18),
              label: const Text('Hide spoiler'),
            ),
      ],
    );
  }

  Widget _likeRow(ThemeData theme) {
    final review = _review;
    final String tooltip;
    VoidCallback? onPressed;
    if (review.isMine) {
      tooltip = 'This is your review';
    } else if (!widget.isSignedIn) {
      tooltip = 'Sign in to like reviews';
      onPressed = widget.onLike == null ? null : _like;
    } else {
      tooltip = review.likedByMe ? 'Unlike this review' : 'Like this review';
      onPressed = widget.onLike == null || _liking ? null : _like;
    }

    final count = review.likeCount;
    return Row(
      children: [
        Tooltip(
          message: tooltip,
          child: TextButton.icon(
            onPressed: onPressed,
            style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(
                review.likedByMe
                    ? Icons.thumb_up_alt
                    : Icons.thumb_up_alt_outlined,
                key: ValueKey(review.likedByMe),
                size: 18,
              ),
            ),
            label: Text(
              count == 1 ? '1 like' : '$count likes',
              semanticsLabel: '$count likes. $tooltip',
            ),
          ),
        ),
      ],
    );
  }

  Widget _menu() {
    return PopupMenuButton<String>(
      tooltip: 'Review actions',
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            widget.onEdit?.call();
          case 'delete':
            widget.onDelete?.call();
          case 'report':
            showReportReviewDialog(context);
        }
      },
      itemBuilder: (context) => [
        if (_canEdit)
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('Edit'),
            ),
          ),
        if (_canDelete)
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(_review.isMine ? 'Delete' : 'Delete (admin)'),
            ),
          ),
        if (_canReport)
          const PopupMenuItem(
            value: 'report',
            child: ListTile(
              leading: Icon(Icons.flag_outlined),
              title: Text('Report'),
            ),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.badge});

  final ReviewBadge badge;

  @override
  Widget build(BuildContext context) {
    final mostLiked = badge == ReviewBadge.mostLiked;
    final color = mostLiked
        ? kStarColor
        : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            mostLiked ? Icons.emoji_events_outlined : Icons.push_pin_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            mostLiked ? 'Most liked' : 'Your review',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 20,
      backgroundColor: colors.primaryContainer,
      foregroundColor: colors.onPrimaryContainer,
      foregroundImage: review.hasAvatar
          ? CachedNetworkImageProvider(review.authorAvatarUrl!)
          : null,
      child: Text(
        review.authorInitial,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _AuthorLine extends StatelessWidget {
  const _AuthorLine({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final score = review.score;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          review.isMine ? '${review.authorName} (you)' : review.authorName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 3),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 2,
          children: [
            if (score != null) ...[
              StarRatingDisplay(value: score.toDouble(), size: 14),
              Text(ReviewRules.scoreLabel(score) ?? '', style: muted),
            ],
            Text(
              review.edited
                  ? '${relativeTime(review.createdAt)} · edited'
                  : relativeTime(review.createdAt),
              style: muted,
            ),
          ],
        ),
      ],
    );
  }
}

class _SpoilerCover extends StatelessWidget {
  const _SpoilerCover({required this.onReveal});

  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.visibility_off_outlined, color: colors.error),
          const SizedBox(height: 8),
          const Text('This review contains spoilers.'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onReveal,
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('Show review'),
          ),
        ],
      ),
    );
  }
}