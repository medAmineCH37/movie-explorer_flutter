import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/auth_repository.dart';
import '../models/user_model.dart';

class AuthService implements AuthRepository {
  final SupabaseClient _client = Supabase.instance.client;

  @override
  User? get currentUser => _client.auth.currentUser;

  @override
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final cleanEmail = email.trim();
      final cleanName = displayName.trim();

      final response = await _client.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {
          'display_name': cleanName,
          'role': 'user',
          'valide': true,
          'is_subscribed': false,
        },
        emailRedirectTo: 'io.supabase.cinea://login-callback/',
      );

      final user = response.user;
      if (user != null) {
        try {
          await _client.from('profiles').upsert({
            'id': user.id,
            'email': cleanEmail,
            'display_name': cleanName,
            'username': cleanName,
            'role': 'user',
            'valide': true,
            'is_subscribed': false,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          debugPrint(
            '⚠️ Erreur upsert profil (colonne email à vérifier dans Supabase) : $e',
          );
        }
      }

      return response;
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Erreur lors de l\'inscription : $e');
    }
  }

  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Erreur lors de la connexion : $e');
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: 'io.supabase.cinea://reset-password/',
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Erreur réinitialisation : $e');
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Erreur mise à jour mot de passe : $e');
    }
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Future<UserModel?> getProfile(String userId, String email) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data == null) {
        final newProfile = {
          'id': userId,
          'email': email,
          'display_name':
              currentUser?.userMetadata?['display_name'] ?? 'Cinéphile',
          'role': 'user',
          'valide': true,
          'is_subscribed': false,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        await _client.from('profiles').upsert(newProfile);

        return UserModel(
          id: userId,
          email: email,
          name: newProfile['display_name'] as String,
          role: 'user',
          valide: true,
          isSubscribed: false,
        );
      }

      final String profileEmail = (data['email'] as String?)?.isNotEmpty == true
          ? (data['email'] as String)
          : email;

      return UserModel.fromJson(data, profileEmail);
    } catch (e) {
      return UserModel(
        id: userId,
        email: email,
        name: currentUser?.userMetadata?['display_name'] ?? 'Cinéphile',
        role: 'user',
        valide: true,
        isSubscribed: false,
      );
    }
  }

  @override
  Future<void> updateSubscription(String userId, bool nextState) async {
    await _client
        .from('profiles')
        .update({
          'is_subscribed': nextState,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId);
  }

  @override
  Future<List<UserModel>> getAllUsers() async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;

      return data.map((json) {
        final userEmail = (json['email'] as String?)?.isNotEmpty == true
            ? json['email'] as String
            : 'utilisateur@cinea.app';
        return UserModel.fromJson(json, userEmail);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<UserModel?> getUserById(String userId) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data == null) return null;
      final email = (data['email'] as String?)?.isNotEmpty == true
          ? data['email'] as String
          : 'utilisateur@cinea.app';
      return UserModel.fromJson(data, email);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> toggleUserValidation(
    String userId,
    bool currentValideStatus,
  ) async {
    await _client
        .from('profiles')
        .update({
          'valide': !currentValideStatus,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId);
  }

  @override
  Future<void> updateUserRole(String userId, String nextRole) async {
    await _client
        .from('profiles')
        .update({
          'role': nextRole.toLowerCase(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId);
  }
}
