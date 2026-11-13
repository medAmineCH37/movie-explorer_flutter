/// Business rules shared by the Ratings & Reviews screens.
///
/// The same limits are enforced by the database (CHECK constraints and
/// triggers in `supabase/migrations/20261111_ratings_reviews.sql`); the app
/// validates first only to give immediate feedback.
abstract final class ReviewRules {
  static const int minScore = 1;
  static const int maxScore = 5;

  static const int minContentLength = 3;
  static const int maxContentLength = 1000;

  static const int minReportReasonLength = 3;
  static const int maxReportReasonLength = 300;

  /// Reviews longer than this are truncated behind "Read more".
  static const int truncateAt = 280;

  static const int pageSize = 10;

  static const Map<int, String> scoreLabels = {
    1: 'Poor',
    2: 'Average',
    3: 'Good',
    4: 'Very good',
    5: 'Masterpiece',
  };

  static String? scoreLabel(int? score) => scoreLabels[score];

  /// Error message for review [content], or `null` when it is valid.
  static String? validateContent(String content) {
    final length = content.trim().length;
    if (length < minContentLength) {
      return 'Your review needs at least $minContentLength characters.';
    }
    if (length > maxContentLength) {
      return 'Your review cannot exceed $maxContentLength characters.';
    }
    return null;
  }

  /// Error message for a report [reason], or `null` when it is valid.
  static String? validateReportReason(String reason) {
    final length = reason.trim().length;
    if (length < minReportReasonLength) {
      return 'Give a reason of at least $minReportReasonLength characters.';
    }
    if (length > maxReportReasonLength) {
      return 'The reason cannot exceed $maxReportReasonLength characters.';
    }
    return null;
  }
}
