import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/auth_repository.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _supabase;

  AuthRepositoryImpl(this._supabase);

  @override
  User? get currentUser => _supabase.auth.currentUser;

  @override
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );

    final user = response.user;
    if (user != null) {
      // Création explicite du profil dans public.profiles avec rôle par défaut 'user'
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'display_name': displayName,
        'username': displayName,
        'role': 'user',
        'valide': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
    return response;
  }

  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    await _supabase.auth.updateUser(UserAttributes(password: newPassword));
  }

  @override
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// 🟢 LECTURE DU PROFIL & RÔLE DEPUIS PUBLIC.PROFILES
  @override
  Future<UserModel?> getProfile(String userId, String email) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        return UserModel(
          id: userId,
          email: email,
          name: email.isNotEmpty ? email.split('@').first : 'Movie fan',
          role: 'user',
          valide: true,
        );
      }

      // Extraction dynamique du nom et de l'email effectif
      final String effectiveEmail = email.isNotEmpty
          ? email
          : (_supabase.auth.currentUser?.id == userId
                ? (_supabase.auth.currentUser?.email ?? '')
                : '');

      return UserModel.fromSupabase(response, effectiveEmail);
    } catch (e) {
      return null;
    }
  }

  // --- Méthodes d'Administration PWA ---

  @override
  Future<List<UserModel>> getAllUsers() async {
    final response = await _supabase
        .from('profiles')
        .select()
        .order('created_at', ascending: false);

    final List<dynamic> dataList = response as List<dynamic>;

    return dataList.map((data) {
      final String uId = data['id'] as String;

      // Résolution intelligente de l'adresse email :
      // 1. Si c'est l'utilisateur actuellement connecté -> email réel de Supabase Auth
      // 2. Sinon -> fallback basé sur le nom d'utilisateur/display_name
      String resolvedEmail = '';
      if (_supabase.auth.currentUser?.id == uId) {
        resolvedEmail = _supabase.auth.currentUser?.email ?? '';
      } else {
        final String displayName =
            (data['display_name'] ?? data['username'] ?? 'user')
                .toString()
                .replaceAll(' ', '')
                .toLowerCase();
        resolvedEmail = '$displayName@esprit.tn';
      }

      return UserModel.fromSupabase(data, resolvedEmail);
    }).toList();
  }

  @override
  Future<UserModel?> getUserById(String userId) async {
    final data = await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (data == null) return null;

    final String resolvedEmail = (_supabase.auth.currentUser?.id == userId)
        ? (_supabase.auth.currentUser?.email ?? '')
        : '${(data['username'] ?? data['display_name'] ?? 'user').toString().replaceAll(' ', '').toLowerCase()}@esprit.tn';

    return UserModel.fromSupabase(data, resolvedEmail);
  }

  @override
  Future<void> toggleUserValidation(
    String userId,
    bool currentValideStatus,
  ) async {
    await _supabase
        .from('profiles')
        .update({
          'valide': !currentValideStatus,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId);
  }

  @override
  Future<void> updateUserRole(String userId, String nextRole) async {
    await _supabase
        .from('profiles')
        .update({
          'role': nextRole.toLowerCase(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId);
  }
}
