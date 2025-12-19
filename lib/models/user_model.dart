import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl; // Added field
  final String nativeLanguage;

  // Tracks the ACTIVE language (e.g., 'fr')
  final String currentLanguage;

  // Tracks the HISTORY of all languages the user has started
  final List<String> targetLanguages;

  // Tracks IDs of levels completed
  final List<String> completedLevels;

  final DateTime createdAt;
  final bool isPremium;
  
  // --- TRACKING & GAMIFICATION ---
  final int xp; // Total experience points
  final int streakDays; // Current daily streak
  final DateTime? lastLoginDate; // Used to calculate streaks
  final int lessonsCompleted; // Total count of finished lessons
  final int totalListeningMinutes; // Cumulative time spent in media players

  // Mapping of language code to level (e.g., {'fr': 'A2 - Elementary'})
  final Map<String, String> languageLevels;

  UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl, // Added to constructor
    this.nativeLanguage = 'en',
    this.currentLanguage = '',
    this.targetLanguages = const [],
    this.completedLevels = const [],
    required this.createdAt,
    this.isPremium = false,
    this.xp = 0,
    this.languageLevels = const {},
    this.streakDays = 0,
    this.lastLoginDate,
    this.lessonsCompleted = 0,
    this.totalListeningMinutes = 0,
  });

  // Helper to get the level of the language currently being studied
  String get currentLevel {
    return languageLevels[currentLanguage] ?? 'A1 - Newcomer';
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return UserModel(
      id: id,
      email: map['email']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? '',
      photoUrl: map['photoUrl']?.toString(), // Added mapping
      nativeLanguage: map['nativeLanguage']?.toString() ?? 'en',
      currentLanguage: map['currentLanguage']?.toString() ?? '',
      
      targetLanguages: (map['targetLanguages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [],

      completedLevels: (map['completedLevels'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [],

      createdAt: parseDate(map['createdAt']),
      
      isPremium: map['isPremium'] == true,
      
      xp: (map['xp'] as num?)?.toInt() ?? 0,
      streakDays: (map['streakDays'] as num?)?.toInt() ?? 0,
      lessonsCompleted: (map['lessonsCompleted'] as num?)?.toInt() ?? 0,
      totalListeningMinutes: (map['totalListeningMinutes'] as num?)?.toInt() ?? 0,
      
      lastLoginDate: map['lastLoginDate'] != null ? parseDate(map['lastLoginDate']) : null,

      languageLevels: (map['languageLevels'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value.toString()),
          ) ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl, // Added to map
      'nativeLanguage': nativeLanguage,
      'currentLanguage': currentLanguage,
      'targetLanguages': targetLanguages,
      'completedLevels': completedLevels,
      'isPremium': isPremium,
      'xp': xp,
      'streakDays': streakDays,
      'lessonsCompleted': lessonsCompleted,
      'totalListeningMinutes': totalListeningMinutes,
      'languageLevels': languageLevels,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginDate': lastLoginDate != null ? Timestamp.fromDate(lastLoginDate!) : null,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl, // Added to copyWith
    String? nativeLanguage,
    String? currentLanguage,
    List<String>? targetLanguages,
    List<String>? completedLevels,
    DateTime? createdAt,
    bool? isPremium,
    int? xp,
    Map<String, String>? languageLevels,
    int? streakDays,
    DateTime? lastLoginDate,
    int? lessonsCompleted,
    int? totalListeningMinutes,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl, // Logic to keep existing photo if not provided
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      currentLanguage: currentLanguage ?? this.currentLanguage,
      targetLanguages: targetLanguages ?? this.targetLanguages,
      completedLevels: completedLevels ?? this.completedLevels,
      createdAt: createdAt ?? this.createdAt,
      isPremium: isPremium ?? this.isPremium,
      xp: xp ?? this.xp,
      languageLevels: languageLevels ?? this.languageLevels,
      streakDays: streakDays ?? this.streakDays,
      lastLoginDate: lastLoginDate ?? this.lastLoginDate,
      lessonsCompleted: lessonsCompleted ?? this.lessonsCompleted,
      totalListeningMinutes: totalListeningMinutes ?? this.totalListeningMinutes,
    );
  }
}