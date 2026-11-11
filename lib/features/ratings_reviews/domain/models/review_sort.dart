import 'review.dart';

enum ReviewSort {
  recent('recent', 'Most recent'),
  likes('likes', 'Most liked'),
  highest('highest', 'Highest rated'),
  lowest('lowest', 'Lowest rated');

  const ReviewSort(this.value, this.label);

  /// Value understood by the `get_reviews` database function.
  final String value;
  final String label;
}

/// One page of reviews.
class ReviewPage {
  const ReviewPage({
    required this.reviews,
    required this.page,
    required this.total,
    required this.pageSize,
  });

  final List<Review> reviews;
  final int page;
  final int total;
  final int pageSize;

  int get totalPages => total == 0 ? 1 : (total + pageSize - 1) ~/ pageSize;
  bool get hasPrevious => page > 1;
  bool get hasNext => page < totalPages;
}

/// Reviews shown on the movie page: the viewer's own review first, then the
/// most liked one (if it has likes and is not the viewer's), then the
/// latest three that are neither of those.
class ReviewHighlights {
  const ReviewHighlights({this.mine, this.top, this.latest = const []});

  static const int latestCount = 3;

  final Review? mine;
  final Review? top;
  final List<Review> latest;

  factory ReviewHighlights.compose({
    required Review? mine,
    required Review? mostLiked,
    required List<Review> recent,
  }) {
    final top = mostLiked != null && mostLiked.likeCount > 0
        ? (mostLiked.isMine || mostLiked.id == mine?.id ? null : mostLiked)
        : null;
    final excluded = {?mine?.id, ?top?.id};
    return ReviewHighlights(
      mine: mine,
      top: top,
      latest: recent
          .where((r) => !excluded.contains(r.id))
          .take(latestCount)
          .toList(),
    );
  }

  bool get isEmpty => mine == null && top == null && latest.isEmpty;
}
