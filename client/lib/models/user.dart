class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? gender;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.gender,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      gender: json['gender'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'gender': gender,
    };
  }

  // Get the first letter of the user's first name
  String get firstNameInitial {
    if (name.isEmpty) return 'U';
    final first = name.trim().split(' ').first;
    return first.isNotEmpty ? first[0].toUpperCase() : 'U';
  }
} 