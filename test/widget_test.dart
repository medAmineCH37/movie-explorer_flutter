
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:movie_explorer/app/home_page.dart';
import 'package:movie_explorer/features/user_management/domain/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  User? get currentUser => null;

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('Movie Explorer home screen loads', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(authService: FakeAuthRepository()),
      ),
    );

    expect(find.text('Movie Explorer'), findsOneWidget);
    expect(find.text('YOUR NEXT MOVIE NIGHT'), findsOneWidget);
  });
}
