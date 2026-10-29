
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AuthRepository {
  User? get currentUser;

  Future<void> signOut();
}
