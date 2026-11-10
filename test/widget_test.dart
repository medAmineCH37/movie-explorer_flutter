import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movie_explorer/app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://supabase.co',
      publishableKey: 'dummy-anon-key',
    );
  });

  testWidgets('MovieExplorerApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MovieExplorerApp(),
      ),
    );

    await tester.pump();
    expect(find.text('Movie Explorer'), findsOneWidget);
  });
}
