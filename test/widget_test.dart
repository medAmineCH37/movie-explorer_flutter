
import 'package:flutter_test/flutter_test.dart';
import 'package:movie_explorer/app.dart';

void main() {
  testWidgets('Movie Explorer home screen loads', (tester) async {
    await tester.pumpWidget(const MovieExplorerApp());

    expect(find.text('Movie Explorer'), findsOneWidget);
    expect(find.text('YOUR NEXT MOVIE NIGHT'), findsOneWidget);
  });
}
