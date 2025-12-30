import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  // --- IDENTITY ---
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String? bio; // NEW: Profile biography

  // --- LANGUAGE SETTINGS ---
  final String nativeLanguage;
  final String currentLanguage; // Active language (e.g., 'fr')
  final List<String> targetLanguages; // History of started languages
  final Map<String, String> languageLevels; // Map code to level (e.g., 'fr': 'A2')
  final List<String> completedLevels; // IDs of finished levels

  // --- SUBSCRIPTION ---
  final DateTime createdAt;
  final bool isPremium;
  final Map<String, dynamic>? premiumDetails;

  // --- GAMIFICATION & STATS ---
  final int xp;
  final int streakDays;
  final DateTime? lastLoginDate;
  final int lessonsCompleted;
  final int totalListeningMinutes;
  final int dailyGoalMinutes; // NEW: User's daily target (e.g. 15)
  final List<String> badges; // NEW: Earned achievement IDs

  // --- SOCIAL (FUTURE PROOFING) ---
  final List<String> friends; // NEW: IDs of mutual friends
  final List<String> following; // NEW: IDs of tutors/users followed
  final List<String> followers; // NEW: IDs of users following me
  final List<String> blockedUsers; // NEW: Safety/Moderation

  UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.bio,
    this.nativeLanguage = 'en',
    this.currentLanguage = '',
    this.targetLanguages = const [],
    this.languageLevels = const {},
    this.completedLevels = const [],
    required this.createdAt,
    this.isPremium = false,
    this.premiumDetails,
    this.xp = 0,
    this.streakDays = 0,
    this.lastLoginDate,
    this.lessonsCompleted = 0,
    this.totalListeningMinutes = 0,
    this.dailyGoalMinutes = 15, // Default goal
    this.badges = const [],
    this.friends = const [],
    this.following = const [],
    this.followers = const [],
    this.blockedUsers = const [],
  });

  // Helper: Current level description
  String get currentLevel {
    return languageLevels[currentLanguage] ?? 'A1 - Newcomer';
  }

  // Helper: Check relationship
  bool isFriend(String userId) => friends.contains(userId);
  bool isFollowing(String userId) => following.contains(userId);

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    // Helper to safely parse lists of strings
    List<String> parseList(String key) {
      return (map[key] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    }

    return UserModel(
      id: id,
      email: map['email']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? '',
      photoUrl: map['photoUrl']?.toString(),
      bio: map['bio']?.toString(),
      
      nativeLanguage: map['nativeLanguage']?.toString() ?? 'en',
      currentLanguage: map['currentLanguage']?.toString() ?? '',
      targetLanguages: parseList('targetLanguages'),
      languageLevels: (map['languageLevels'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value.toString()),
          ) ?? {},
      completedLevels: parseList('completedLevels'),

      createdAt: parseDate(map['createdAt']),
      isPremium: map['isPremium'] == true,
      premiumDetails: map['premiumDetails'] != null
          ? Map<String, dynamic>.from(map['premiumDetails'])
          : null,

      xp: (map['xp'] as num?)?.toInt() ?? 0,
      streakDays: (map['streakDays'] as num?)?.toInt() ?? 0,
      lastLoginDate: map['lastLoginDate'] != null
          ? parseDate(map['lastLoginDate'])
          : null,
      lessonsCompleted: (map['lessonsCompleted'] as num?)?.toInt() ?? 0,
      totalListeningMinutes: (map['totalListeningMinutes'] as num?)?.toInt() ?? 0,
      dailyGoalMinutes: (map['dailyGoalMinutes'] as num?)?.toInt() ?? 15,
      
      badges: parseList('badges'),
      friends: parseList('friends'),
      following: parseList('following'),
      followers: parseList('followers'),
      blockedUsers: parseList('blockedUsers'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'bio': bio,
      'nativeLanguage': nativeLanguage,
      'currentLanguage': currentLanguage,
      'targetLanguages': targetLanguages,
      'languageLevels': languageLevels,
      'completedLevels': completedLevels,
      'createdAt': Timestamp.fromDate(createdAt),
      'isPremium': isPremium,
      'premiumDetails': premiumDetails,
      'xp': xp,
      'streakDays': streakDays,
      'lastLoginDate': lastLoginDate != null ? Timestamp.fromDate(lastLoginDate!) : null,
      'lessonsCompleted': lessonsCompleted,
      'totalListeningMinutes': totalListeningMinutes,
      'dailyGoalMinutes': dailyGoalMinutes,
      'badges': badges,
      'friends': friends,
      'following': following,
      'followers': followers,
      'blockedUsers': blockedUsers,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    String? bio,
    String? nativeLanguage,
    String? currentLanguage,
    List<String>? targetLanguages,
    Map<String, String>? languageLevels,
    List<String>? completedLevels,
    DateTime? createdAt,
    bool? isPremium,
    Map<String, dynamic>? premiumDetails,
    int? xp,
    int? streakDays,
    DateTime? lastLoginDate,
    int? lessonsCompleted,
    int? totalListeningMinutes,
    int? dailyGoalMinutes,
    List<String>? badges,
    List<String>? friends,
    List<String>? following,
    List<String>? followers,
    List<String>? blockedUsers,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      currentLanguage: currentLanguage ?? this.currentLanguage,
      targetLanguages: targetLanguages ?? this.targetLanguages,
      languageLevels: languageLevels ?? this.languageLevels,
      completedLevels: completedLevels ?? this.completedLevels,
      createdAt: createdAt ?? this.createdAt,
      isPremium: isPremium ?? this.isPremium,
      premiumDetails: premiumDetails ?? this.premiumDetails,
      xp: xp ?? this.xp,
      streakDays: streakDays ?? this.streakDays,
      lastLoginDate: lastLoginDate ?? this.lastLoginDate,
      lessonsCompleted: lessonsCompleted ?? this.lessonsCompleted,
      totalListeningMinutes: totalListeningMinutes ?? this.totalListeningMinutes,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      badges: badges ?? this.badges,
      friends: friends ?? this.friends,
      following: following ?? this.following,
      followers: followers ?? this.followers,
      blockedUsers: blockedUsers ?? this.blockedUsers,
    );
  }
}