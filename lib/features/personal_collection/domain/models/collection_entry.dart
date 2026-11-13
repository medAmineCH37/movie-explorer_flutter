enum WatchPriority {
  high('high', 'High'),
  medium('medium', 'Medium'),
  low('low', 'Low');

  const WatchPriority(this.value, this.label);

  final String value;
  final String label;

  static WatchPriority fromValue(Object? value) =>
      WatchPriority.values.firstWhere(
        (priority) => priority.value == value,
        orElse: () => WatchPriority.medium,
      );
}

class CollectionEntry {
  const CollectionEntry({
    required this.movieId,
    this.priority = WatchPriority.medium,
    this.watchedAt,
  });

  final int movieId;
  final WatchPriority priority;
  final DateTime? watchedAt;
}
