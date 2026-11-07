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
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'display_name': displayName.trim(),
          'role': 'user',
          'valide': false,         // En attente de validation par mail
          'is_subscribed': false,  // Compte gratuit au départ
        },
        emailRedirectTo: 'io.supabase.cinea://login-callback/',
      );

      if (response.session == null && response.user != null) {
        debugPrint('Email de confirmation envoyé avec succès via Mailtrap.');
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
      debugPrint('Lien de réinitialisation envoyé dans Mailtrap.');
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Erreur lors de l\'envoi du mail de réinitialisation : $e');
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      debugPrint('Mot de passe mis à jour avec succès.');
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du mot de passe : $e');
    }
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// 🛡️ Récupération du profil public SÉCURISÉE (Conforme à votre UserModel)
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
          'display_name': currentUser?.userMetadata?['display_name'] ?? 'Cinéphile',
          'role': 'user',
          'valide': true,
          'is_subscribed': false,
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

      return UserModel.fromJson(data, email);
    } catch (e) {
      debugPrint('⚠️ Erreur lors du fetch de profil : $e');
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

  /// Mise à jour de l'abonnement
  Future<void> updateSubscription(String userId, bool nextState) async {
    await _client
        .from('profiles')
        .update({'is_subscribed': nextState})
        .eq('id', userId);
  }
}