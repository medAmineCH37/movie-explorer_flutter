/// "just now", "5 minutes ago", "yesterday", "3 weeks ago", "2 years ago".
String relativeTime(DateTime date, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(date);
  if (diff.isNegative || diff.inSeconds < 60) return 'just now';

  String ago(int value, String unit) =>
      '$value $unit${value == 1 ? '' : 's'} ago';

  if (diff.inMinutes < 60) return ago(diff.inMinutes, 'minute');
  if (diff.inHours < 24) return ago(diff.inHours, 'hour');
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return ago(diff.inDays, 'day');
  if (diff.inDays < 30) return ago(diff.inDays ~/ 7, 'week');
  if (diff.inDays < 365) return ago(diff.inDays ~/ 30, 'month');
  return ago(diff.inDays ~/ 365, 'year');
}
