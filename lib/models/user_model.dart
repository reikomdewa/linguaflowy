class UserModel {
  final String id;
  final String email;
  final String displayName;
  final String nativeLanguage;
  final String currentLanguage; // New field
  final List<String> targetLanguages;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.nativeLanguage = 'en',
    this.currentLanguage = 'es', // Default to Spanish or your choice
    this.targetLanguages = const [],
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      email: map['email']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? '',
      nativeLanguage: map['nativeLanguage']?.toString() ?? 'en',
      currentLanguage: map['currentLanguage']?.toString() ?? 'es', // Load from DB
      targetLanguages: (map['targetLanguages'] as List<dynamic>?)
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
      'currentLanguage': currentLanguage, // Save to DB
      'targetLanguages': targetLanguages,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Helper to create a new instance with updated fields
  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? nativeLanguage,
    String? currentLanguage,
    List<String>? targetLanguages,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      currentLanguage: currentLanguage ?? this.currentLanguage,
      targetLanguages: targetLanguages ?? this.targetLanguages,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}