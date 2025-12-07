class UserModel {
  final String id;
  final String email;
  final String displayName;
  final String nativeLanguage;
  
  // FIX 1: This tracks the ACTIVE language. Defaults to empty for new users.
  final String currentLanguage; 
  
  // FIX 2: This tracks the HISTORY of all languages the user has started.
  final List<String> targetLanguages; 
  
  final DateTime createdAt;
  final bool isPremium;
  final int xp;
  final Map<String, String> languageLevels; 

  UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.nativeLanguage = 'en',
    
    // --- CHANGED: Default is now empty string (triggers Selector on Home) ---
    this.currentLanguage = '', 
    
    this.targetLanguages = const [],
    required this.createdAt,
    this.isPremium = false,
    this.xp = 0,
    this.languageLevels = const {}, 
  });

  String get currentLevel {
    // Return 'A1 - Newcomer' if the map doesn't have an entry for the current language
    return languageLevels[currentLanguage] ?? 'A1 - Newcomer';
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      email: map['email']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? '',
      nativeLanguage: map['nativeLanguage']?.toString() ?? 'en',
      
      // --- CHANGED: If null in DB, default to '' ---
      currentLanguage: map['currentLanguage']?.toString() ?? '',
      
      // Load the history list safely
      targetLanguages:
          (map['targetLanguages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
          
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is String 
              ? DateTime.parse(map['createdAt']) 
              : (map['createdAt'] as dynamic).toDate()) // Handle Firestore Timestamp
          : DateTime.now(),
      
      isPremium: map['isPremium'] == true,
      xp: (map['xp'] as num?)?.toInt() ?? 0,
      
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
      'targetLanguages': targetLanguages, // Saves the history list
      'createdAt': createdAt.toIso8601String(),
      'isPremium': isPremium,
      'xp': xp,
      'languageLevels': languageLevels,
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
    Map<String, String>? languageLevels,
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
      languageLevels: languageLevels ?? this.languageLevels,
    );
  }
}