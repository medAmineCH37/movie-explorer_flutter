class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.valide,
    this.createdAt,
    this.updatedAt,
    this.isSubscribed = false,
  });

  final String id;
  final String email;
  final String name;
  final String role;
  final bool valide;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isSubscribed;

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
      createdAt: profileJson['created_at'] != null
          ? DateTime.tryParse(profileJson['created_at'].toString())
          : null,

      updatedAt: profileJson['updated_at'] != null
          ? DateTime.tryParse(profileJson['updated_at'].toString())
          : null,

      isSubscribed: profileJson['is_subscribed'] ?? false,
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
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSubscribed,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      valide: valide ?? this.valide,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSubscribed: isSubscribed ?? this.isSubscribed,
    );
  }
}
