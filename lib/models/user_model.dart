import 'package:cloud_firestore/cloud_firestore.dart'; 

class UserModel {
  final String id;
  final String email;
  final String displayName;
  final String nativeLanguage;
  
  // Tracks the ACTIVE language. Defaults to empty for new users.
  final String currentLanguage; 
  
  // Tracks the HISTORY of all languages the user has started.
  final List<String> targetLanguages; 
  
  // Tracks completed unit IDs (e.g., ['es_u01_basics', ...])
  final List<String> completedLevels; 

  final DateTime createdAt;
  final bool isPremium;
  final int xp;
  final Map<String, String> languageLevels; 

  // --- NEW STATS FIELDS ---
  final int streakDays;
  final DateTime? lastLoginDate;
  final int lessonsCompleted;
  final int totalListeningMinutes;

  UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.nativeLanguage = 'en',
    this.currentLanguage = '', 
    this.targetLanguages = const [],
    this.completedLevels = const [], 
    required this.createdAt,
    this.isPremium = false,
    this.xp = 0,
    this.languageLevels = const {}, 
    // Defaults for new stats
    this.streakDays = 0,
    this.lastLoginDate,
    this.lessonsCompleted = 0,
    this.totalListeningMinutes = 0,
  });

  String get currentLevel {
    return languageLevels[currentLanguage] ?? 'A1 - Newcomer';
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      email: map['email']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? '',
      nativeLanguage: map['nativeLanguage']?.toString() ?? 'en',
      currentLanguage: map['currentLanguage']?.toString() ?? '',
      
      // Load target languages history
      targetLanguages:
          (map['targetLanguages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],

      // Map the completed levels
      completedLevels:
          (map['completedLevels'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
          
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is String 
              ? DateTime.parse(map['createdAt']) 
              : (map['createdAt'] as Timestamp).toDate()) 
          : DateTime.now(),
      
      isPremium: map['isPremium'] == true,
      xp: (map['xp'] as num?)?.toInt() ?? 0,
      
      languageLevels: (map['languageLevels'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value.toString()),
          ) ??
          {},

      // --- NEW STATS MAPPING ---
      streakDays: (map['streakDays'] as num?)?.toInt() ?? 0,
      
      lessonsCompleted: (map['lessonsCompleted'] as num?)?.toInt() ?? 0,
      
      totalListeningMinutes: (map['totalListeningMinutes'] as num?)?.toInt() ?? 0,
      
      // Handle lastLoginDate (supports both String and Timestamp)
      lastLoginDate: map['lastLoginDate'] != null
          ? (map['lastLoginDate'] is String
              ? DateTime.tryParse(map['lastLoginDate'])
              : (map['lastLoginDate'] as Timestamp).toDate())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'nativeLanguage': nativeLanguage,
      'currentLanguage': currentLanguage,
      'targetLanguages': targetLanguages,
      'completedLevels': completedLevels,
      'createdAt': createdAt.toIso8601String(),
      'isPremium': isPremium,
      'xp': xp,
      'languageLevels': languageLevels,
      // --- NEW STATS TO MAP ---
      'streakDays': streakDays,
      'lastLoginDate': lastLoginDate?.toIso8601String(), // Saving as ISO String
      'lessonsCompleted': lessonsCompleted,
      'totalListeningMinutes': totalListeningMinutes,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? nativeLanguage,
    String? currentLanguage,
    List<String>? targetLanguages,
    List<String>? completedLevels,
    DateTime? createdAt,
    bool? isPremium,
    int? xp,
    Map<String, String>? languageLevels,
    // New fields in copyWith
    int? streakDays,
    DateTime? lastLoginDate,
    int? lessonsCompleted,
    int? totalListeningMinutes,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      currentLanguage: currentLanguage ?? this.currentLanguage,
      targetLanguages: targetLanguages ?? this.targetLanguages,
      completedLevels: completedLevels ?? this.completedLevels,
      createdAt: createdAt ?? this.createdAt,
      isPremium: isPremium ?? this.isPremium,
      xp: xp ?? this.xp,
      languageLevels: languageLevels ?? this.languageLevels,
      // New fields assignment
      streakDays: streakDays ?? this.streakDays,
      lastLoginDate: lastLoginDate ?? this.lastLoginDate,
      lessonsCompleted: lessonsCompleted ?? this.lessonsCompleted,
      totalListeningMinutes: totalListeningMinutes ?? this.totalListeningMinutes,
    );
  }
}