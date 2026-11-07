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

  factory UserModel.fromJson(Map<String, dynamic> json, String userEmail) {
    return UserModel(
      id: json['id'] ?? '',
      email: userEmail,
      name: json['username'] ?? json['display_name'] ?? 'Cinéphile',
      role: json['role'] ?? 'user',
      valide: json['valide'] ?? true,
      isSubscribed: json['is_subscribed'] ?? true,
    );
  }
}
