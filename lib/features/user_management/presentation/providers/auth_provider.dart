import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/user_model.dart';
import '../../data/services/auth_service.dart';

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  AuthState({this.user, this.isLoading = false, this.error});

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    bool clearUser = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  final AuthService _service = AuthService();

  @override
  AuthState build() {
    final subscription = _service.authStateChanges.listen((event) {
      if (event.event == AuthChangeEvent.signedOut) {
        state = AuthState(user: null);
      } else if (event.event == AuthChangeEvent.signedIn ||
          event.event == AuthChangeEvent.tokenRefreshed ||
          event.event == AuthChangeEvent.userUpdated) {
        Future.microtask(_loadSession);
      }
    });
    ref.onDispose(subscription.cancel);
    Future.microtask(() => _loadSession());
    return AuthState(isLoading: true);
  }

  Future<void> _loadSession() async {
    try {
      final curr = _service.currentUser;
      if (curr == null || curr.email == null) {
        state = AuthState(user: null, isLoading: false);
        return;
      }

      final profile = await _service
          .getProfile(curr.id, curr.email!)
          .timeout(const Duration(seconds: 4));

      state = AuthState(user: profile, isLoading: false);
    } catch (_) {
      state = AuthState(user: null, isLoading: false);
    }
  }

  Future<bool> login(String email, String password) async {
    state = AuthState(isLoading: true);
    try {
      final res = await _service
          .signIn(email: email, password: password)
          .timeout(const Duration(seconds: 6));

      final user = res.user;
      if (user != null) {
        UserModel? profile;
        try {
          profile = await _service
              .getProfile(user.id, user.email ?? email)
              .timeout(const Duration(seconds: 4));
        } catch (_) {
          profile = null;
        }

        final effectiveProfile =
            profile ??
            UserModel(
              id: user.id,
              email: user.email ?? email,
              name: email.split('@').first,
              role: 'user',
              valide: true,
            );

        if (!effectiveProfile.valide) {
          await _service
              .signOut(); // Déconnexion immédiate de la session Supabase
          state = AuthState(
            user: null,
            isLoading: false,
            error: 'Accès refusé : votre compte a été bloqué par un administrateur.',
          );
          return false;
        }

        state = AuthState(user: effectiveProfile, isLoading: false);
        return true;
      }
    } on AuthException catch (e) {
      String errorMessage = e.message;
      if (e.message.contains('Invalid login credentials')) {
        errorMessage = 'Adresse e-mail ou mot de passe incorrect.';
      } else if (e.message.contains('Email not confirmed')) {
        errorMessage =
            'Veuillez confirmer votre adresse e-mail avant de vous connecter.';
      }
      state = AuthState(error: errorMessage, isLoading: false);
    } catch (e) {
      state = AuthState(
        error: 'Impossible de se connecter. Vérifiez votre saisie ou votre réseau.',
        isLoading: false,
      );
    }
    return false;
  }

  Future<bool> register(String email, String password, String name) async {
    state = AuthState(isLoading: true);
    try {
      final res = await _service
          .signUp(email: email, password: password, displayName: name)
          .timeout(const Duration(seconds: 6));

      if (res.user != null) {
        state = AuthState(isLoading: false);
        return true;
      }
    } on AuthException catch (e) {
      state = AuthState(error: e.message, isLoading: false);
    } catch (e) {
      state = AuthState(
        error: e.toString().replaceAll('Exception: ', ''),
        isLoading: false,
      );
    }
    return false;
  }

  Future<void> refreshProfile() async {
    await _loadSession();
  }

  // 🟢 EFFACE LES MESSAGES D'ERREUR DANS L'ÉTAT
  void clearError() {
    state = AuthState(
      user: state.user,
      isLoading: state.isLoading,
      error: null,
    );
  }

  // 🚪 DÉCONNEXION PROPRE (Réinitialise l'utilisateur à null)
  Future<void> signOut() async {
    state = AuthState(isLoading: true);
    try {
      await _service.signOut();
    } catch (_) {}
    state = AuthState(user: null, isLoading: false);
  }

  Future<void> logout() async {
    await signOut();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  () => AuthNotifier(),
);
