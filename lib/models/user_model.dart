class UserModel {
  final String id;
  final String email;
  final String displayName;
  final String nativeLanguage;
  final String currentLanguage;
  final List<String> targetLanguages;
  final DateTime createdAt;
  final bool isPremium;
  final int xp;
  
  // --- NEW FIELD: Stores level per language code ---
  final Map<String, String> languageLevels; 

  UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.nativeLanguage = 'en',
    this.currentLanguage = 'es',
    this.targetLanguages = const [],
    required this.createdAt,
    this.isPremium = false,
    this.xp = 0,
    // --- Default to empty map ---
    this.languageLevels = const {}, 
  });

  // --- HELPER: Get level for the currently selected language ---
  String get currentLevel {
    return languageLevels[currentLanguage] ?? 'A1 - Newcomer';
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      email: map['email']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? '',
      nativeLanguage: map['nativeLanguage']?.toString() ?? 'en',
      currentLanguage: map['currentLanguage']?.toString() ?? 'es',
      targetLanguages:
          (map['targetLanguages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'].toString())
          : DateTime.now(),
      isPremium: map['isPremium'] == true,
      xp: (map['xp'] as num?)?.toInt() ?? 0,
      
      // --- Load Levels Map safely ---
      languageLevels: (map['languageLevels'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value.toString()),
          ) ??
          {}, 
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'nativeLanguage': nativeLanguage,
      'currentLanguage': currentLanguage,
      'targetLanguages': targetLanguages,
      'createdAt': createdAt.toIso8601String(),
      'isPremium': isPremium,
      'xp': xp,
      'languageLevels': languageLevels, // --- Save to DB ---
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? nativeLanguage,
    String? currentLanguage,
    List<String>? targetLanguages,
    DateTime? createdAt,
    bool? isPremium,
    int? xp,
    Map<String, String>? languageLevels, // --- Added parameter ---
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      currentLanguage: currentLanguage ?? this.currentLanguage,
      targetLanguages: targetLanguages ?? this.targetLanguages,
      createdAt: createdAt ?? this.createdAt,
      isPremium: isPremium ?? this.isPremium,
      xp: xp ?? this.xp,
      languageLevels: languageLevels ?? this.languageLevels, // --- Update logic ---
    );
  }
}