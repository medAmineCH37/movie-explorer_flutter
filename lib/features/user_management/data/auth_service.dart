
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/auth_repository.dart';

class AuthService implements AuthRepository {
  AuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': displayName.trim()},
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }
}
