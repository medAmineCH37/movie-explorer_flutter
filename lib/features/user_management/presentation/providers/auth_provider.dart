import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/auth_service.dart';
import '../../data/models/user_model.dart';

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  AuthState({this.user, this.isLoading = false, this.error});
}

class AuthNotifier extends Notifier<AuthState> {
  final AuthService _service = AuthService();

  @override
  AuthState build() {
    _loadSession();
    return AuthState();
  }

  void _loadSession() async {
    final curr = _service.currentUser;
    if (curr != null) {
      try {
        final profile = await _service.getProfile(curr.id, curr.email ?? '');
        state = AuthState(user: profile);
      } catch (_) {}
    }
  }

  // 🔓 PROCESSUS DE CONNEXION RÉACTIF
  Future<bool> login(String email, String password) async {
    state = AuthState(isLoading: true);
    try {
      final res = await _service.signIn(email: email, password: password);
      if (res.user != null) {
        final profile = await _service.getProfile(res.user!.id, res.user!.email ?? '');
        state = AuthState(user: profile);
        return true;
      }
    } on AuthException catch (e) {
      state = AuthState(error: e.message);
    } catch (e) {
      state = AuthState(error: e.toString().replaceAll('Exception: ', ''));
    }
    return false;
  }

  // 📝 PROCESSUS D'INSCRIPTION INTERCONNECTÉ
  Future<bool> register(String email, String password, String name) async {
    state = AuthState(isLoading: true);
    try {
      final res = await _service.signUp(email: email, password: password, displayName: name);
      if (res.user != null) {
        state = AuthState(isLoading: false);
        return true;
      }
    } on AuthException catch (e) {
      state = AuthState(error: e.message);
    } catch (e) {
      state = AuthState(error: e.toString().replaceAll('Exception: ', ''));
    }
    return false;
  }

  // 💡 MUTATION DU FORFAIT PREMIUM STREAMING
  Future<void> toggleSubscription() async {
    if (state.user == null) return;
    final nextState = !state.user!.isSubscribed;
    try {
      await _service.updateSubscription(state.user!.id, nextState);
      _loadSession();
    } catch (_) {}
  }

  // 🚪 DÉCONNEXION CENTRALISÉE
  Future<void> logout() async {
    await _service.signOut();
    state = AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() => AuthNotifier());