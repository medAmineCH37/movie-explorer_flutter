/// Business rules for custom lists (pure functions, unit tested).
/// The database enforces the same rules (migration 20261107).
class ListRules {
  ListRules._();

  static const int maxLists = 20;
  static const int maxMoviesPerList = 100;
  static const int nameMin = 2;
  static const int nameMax = 50;
  static const int descriptionMax = 300;

  static String normalizeName(String name) => name.trim();

  /// [existingNames]: the user's other list names (exclude the edited list).
  static String? validateName(String name, Iterable<String> existingNames) {
    final value = normalizeName(name);
    if (value.length < nameMin)
      return 'Name must be at least $nameMin characters.';
    if (value.length > nameMax)
      return 'Name must be at most $nameMax characters.';
    final lower = value.toLowerCase();
    if (existingNames.any((n) => normalizeName(n).toLowerCase() == lower)) {
      return 'You already have a list with this name.';
    }
    return null;
  }

  static String? validateDescription(String description) =>
      description.trim().length > descriptionMax
      ? 'Description must be at most $descriptionMax characters.'
      : null;

  static String? canCreateList(int currentCount) => currentCount >= maxLists
      ? 'You have reached the limit of $maxLists lists.'
      : null;

  static String? canAddMovie({
    required int movieCount,
    required bool alreadyInList,
  }) {
    if (alreadyInList) return 'This movie is already in the list.';
    if (movieCount >= maxMoviesPerList) {
      return 'A list can contain up to $maxMoviesPerList movies.';
    }
    return null;
  }
}
