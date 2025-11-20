// ==========================================
// DATA MODELS
// ==========================================
// File: lib/models/user_model.dart

class UserModel {
  final String id;
  final String email;
  final String displayName;
  final String nativeLanguage;
  final List<String> targetLanguages;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.nativeLanguage = 'en',
    this.targetLanguages = const [],
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      email: map['email']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? '',
      nativeLanguage: map['nativeLanguage']?.toString() ?? 'en',
      targetLanguages:
          (map['targetLanguages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'nativeLanguage': nativeLanguage,
      'targetLanguages': targetLanguages,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
