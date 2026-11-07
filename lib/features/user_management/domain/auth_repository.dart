import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AuthRepository {
  /// Utilisateur actuellement connecté
  User? get currentUser;

  /// Flux d'écoute des changements d'état d'authentification
  Stream<AuthState> get authStateChanges;

  /// Inscription d'un nouvel utilisateur (déclenche l'envoi du mail via Mailtrap)
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  /// Connexion par email / mot de passe
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  });

  /// Demande d'oubli de mot de passe (envoie un mail de réinitialisation via Mailtrap)
  Future<void> sendPasswordResetEmail(String email);

  /// Mise à jour du mot de passe utilisateur
  Future<void> updatePassword(String newPassword);

  /// Déconnexion de l'utilisateur
  Future<void> signOut();
}