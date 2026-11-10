import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/user_model.dart';

abstract class AuthRepository {
  User? get currentUser;
  Stream<AuthState> get authStateChanges;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  });

  Future<void> sendPasswordResetEmail(String email);
  Future<void> updatePassword(String newPassword);
  Future<void> signOut();

  Future<UserModel?> getProfile(String userId, String email);
  Future<void> updateSubscription(String userId, bool nextState);

  // Méthodes d'Administration PWA
  Future<List<UserModel>> getAllUsers();
  Future<UserModel?> getUserById(String userId);
  Future<void> toggleUserValidation(String userId, bool currentValideStatus);
  Future<void> updateUserRole(String userId, String nextRole);
}