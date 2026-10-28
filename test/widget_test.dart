
import 'package:flutter_test/flutter_test.dart';
import 'package:movie_explorer/app.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Movie Explorer home screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(const MovieExplorerApp());

    expect(find.text('Movie Explorer'), findsOneWidget);
    expect(find.text('Explore the app'), findsOneWidget);
    expect(find.text('User Management'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Movie Discovery'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Movie Discovery'), findsOneWidget);
  });
}
