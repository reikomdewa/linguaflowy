import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for Timestamp check if used

class UserModel {
  final String id;
  final String email;
  final String displayName;
  final String nativeLanguage;
  
  // Tracks the ACTIVE language. Defaults to empty for new users.
  final String currentLanguage; 
  
  // Tracks the HISTORY of all languages the user has started.
  final List<String> targetLanguages; 
  
  // FIX: Added this field to track completed unit IDs (e.g., ['es_u01_basics', ...])
  final List<String> completedLevels; 

  final DateTime createdAt;
  final bool isPremium;
  final int xp;
  final Map<String, String> languageLevels; 

  UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.nativeLanguage = 'en',
    this.currentLanguage = '', 
    this.targetLanguages = const [],
    this.completedLevels = const [], // Default to empty
    required this.createdAt,
    this.isPremium = false,
    this.xp = 0,
    this.languageLevels = const {}, 
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

      // FIX: Map the completed levels from Firestore
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'nativeLanguage': nativeLanguage,
      'currentLanguage': currentLanguage,
      'targetLanguages': targetLanguages,
      'completedLevels': completedLevels, // Save to Firestore
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
    List<String>? completedLevels, // Add to copyWith
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
      completedLevels: completedLevels ?? this.completedLevels, // Update logic
      createdAt: createdAt ?? this.createdAt,
      isPremium: isPremium ?? this.isPremium,
      xp: xp ?? this.xp,
      languageLevels: languageLevels ?? this.languageLevels,
    );
  }
}