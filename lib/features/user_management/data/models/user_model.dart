class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.valide,
  });

  final String id;
  final String email;
  final String name;
  final String role;
  final bool valide;

  factory UserModel.fromSupabase(
    Map<String, dynamic> profileJson,
    String authEmail,
  ) {
    return UserModel(
      id: profileJson['id']?.toString() ?? '',
      email: authEmail,
      name:
          profileJson['display_name'] ?? profileJson['username'] ?? 'Cinéphile',
      role: profileJson['role'] ?? 'user',
      valide: profileJson['valide'] ?? true,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json, String userEmail) =>
      UserModel.fromSupabase(json, userEmail);

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? role,
    bool? valide,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      valide: valide ?? this.valide,
    );
  }
}
