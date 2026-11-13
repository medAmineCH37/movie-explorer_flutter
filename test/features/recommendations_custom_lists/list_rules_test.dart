import 'package:flutter_test/flutter_test.dart';

import 'package:movie_explorer/features/recommendations_custom_lists/domain/list_rules.dart';

void main() {
  group('validateName', () {
    test('accepts 2 to 50 characters (trimmed)', () {
      expect(ListRules.validateName('  Sci-Fi  ', []), isNull);
      expect(ListRules.validateName('ab', []), isNull);
      expect(ListRules.validateName('a' * 50, []), isNull);
    });

    test('rejects too short or too long names', () {
      expect(ListRules.validateName(' a ', []), isNotNull);
      expect(ListRules.validateName('a' * 51, []), isNotNull);
    });

    test('names are unique per user, case-insensitive', () {
      expect(ListRules.validateName('SCI-FI', ['Sci-Fi']), isNotNull);
      expect(ListRules.validateName('Horror', ['Sci-Fi']), isNull);
    });
  });

  test('description is limited to 300 characters', () {
    expect(ListRules.validateDescription('a' * 300), isNull);
    expect(ListRules.validateDescription('a' * 301), isNotNull);
  });

  test('a user can have up to 20 lists', () {
    expect(ListRules.canCreateList(19), isNull);
    expect(ListRules.canCreateList(20), isNotNull);
  });

  test('a list holds up to 100 movies, without duplicates', () {
    expect(ListRules.canAddMovie(movieCount: 99, alreadyInList: false), isNull);
    expect(
      ListRules.canAddMovie(movieCount: 100, alreadyInList: false),
      isNotNull,
    );
    expect(
      ListRules.canAddMovie(movieCount: 3, alreadyInList: true),
      isNotNull,
    );
  });
}
