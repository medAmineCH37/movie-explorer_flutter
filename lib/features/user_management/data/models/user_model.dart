class UserModel {
  final String id;
  final String email;
  final String name;
  final String role;
  final bool valide;
  final bool isSubscribed;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.valide,
    required this.isSubscribed,
  });

  /// Factory qui reconstruit l'utilisateur à partir du profil Supabase
  /// et de l'adresse email issue du compte d'authentification.
  factory UserModel.fromSupabase(Map<String, dynamic> profileJson, String authEmail) {
    return UserModel(
      id: profileJson['id']?.toString() ?? '',
      email: authEmail,
      name: profileJson['display_name'] ?? profileJson['username'] ?? 'Cinéphile',
      role: profileJson['role'] ?? 'user',
      valide: profileJson['valide'] ?? true,
      isSubscribed: profileJson['is_subscribed'] ?? false,
    );
  }

  /// Conserve la méthode fromJson pour la compatibilité
  factory UserModel.fromJson(Map<String, dynamic> json, String userEmail) {
    return UserModel.fromSupabase(json, userEmail);
  }

  /// Permet de copier un objet UserModel en modifiant juste certaines valeurs
  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? role,
    bool? valide,
    bool? isSubscribed,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      valide: valide ?? this.valide,
      isSubscribed: isSubscribed ?? this.isSubscribed,
    );
  }
}