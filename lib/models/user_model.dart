import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  // --- 1. IDENTITY & CORE ---
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String? username; // Unique handle (e.g. @asad123)
  final String? bio; 
  final bool isVerified; // Blue tick verification status

  // --- 2. DEMOGRAPHICS & LOCATION (Tandem "Nearby") ---
  final DateTime? birthDate; // Used to calculate age
  final String? gender; // 'male', 'female', 'other', or null
  final String? city;
  final String? country;
  final String? countryCode; // e.g., 'US', 'MA' for flags
  final GeoPoint? location; // Latitude/Longitude for "Nearby" radius search

  // --- 3. LANGUAGE PROFILE ---
  final String nativeLanguage; // Primary native
  final List<String> additionalNativeLanguages; // If they are bilingual
  final String currentLanguage; // The one they are currently focusing on in UI
  final List<String> targetLanguages; // Languages they want to learn
  final Map<String, String> languageLevels; // e.g. {'fr': 'A2', 'es': 'Native'}
  final List<String> completedLevels; // Curriculum progress IDs

  // --- 4. LEARNING PREFERENCES (Tandem Style) ---
  final List<String> topics; // e.g. ["Football", "Tech", "Movies"]
  final String? learningGoal; // e.g. "I need to pass the TOEFL exam"
  final String correctionStyle; // e.g. "gentle", "strict", "every-mistake"
  final List<String> communicationStyles; // e.g. ["text", "audio", "video", "in-person"]
  
  // --- 5. SOCIAL & REPUTATION ---
  final List<UserReference> references; // Reviews from other users
  final bool isOnline;
  final DateTime? lastActiveAt;
  final List<String> friends;
  final List<String> following;
  final List<String> followers;
  final List<String> blockedUsers;

  // --- 6. GAMIFICATION & STATS ---
  final int xp;
  final int streakDays;
  final DateTime? lastLoginDate;
  final int lessonsCompleted;
  final int totalListeningMinutes;
  final int dailyGoalMinutes;
  final List<String> badges;

  // --- 7. SUBSCRIPTION ---
  final DateTime createdAt;
  final bool isPremium;
  final Map<String, dynamic>? premiumDetails;
  
  // --- 8. SEARCH HELPERS ---
  final List<String> searchKeywords; // Lowercase name parts for firestore searching

  UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.username,
    this.bio,
    this.isVerified = false,
    this.birthDate,
    this.gender,
    this.city,
    this.country,
    this.countryCode,
    this.location,
    this.nativeLanguage = 'en',
    this.additionalNativeLanguages = const [],
    this.currentLanguage = '',
    this.targetLanguages = const [],
    this.languageLevels = const {},
    this.completedLevels = const [],
    this.topics = const [],
    this.learningGoal,
    this.correctionStyle = 'gentle',
    this.communicationStyles = const ['text'],
    this.references = const [],
    this.isOnline = false,
    this.lastActiveAt,
    this.friends = const [],
    this.following = const [],
    this.followers = const [],
    this.blockedUsers = const [],
    this.xp = 0,
    this.streakDays = 0,
    this.lastLoginDate,
    this.lessonsCompleted = 0,
    this.totalListeningMinutes = 0,
    this.dailyGoalMinutes = 15,
    this.badges = const [],
    required this.createdAt,
    this.isPremium = false,
    this.premiumDetails,
    this.searchKeywords = const [],
  });

  // --- COMPUTED PROPERTIES ---

  // 1. Calculate Age dynamically
  int? get age {
    if (birthDate == null) return null;
    final now = DateTime.now();
    int age = now.year - birthDate!.year;
    if (now.month < birthDate!.month || 
       (now.month == birthDate!.month && now.day < birthDate!.day)) {
      age--;
    }
    return age;
  }
 int get referenceCount => references.length;
  // 2. Formatted Location
  String get fullLocation {
    if (city != null && country != null) return "$city, $country";
    return country ?? city ?? "Unknown";
  }

  // 3. New User Status (joined in last 7 days)
  bool get isNewUser {
    final diff = DateTime.now().difference(createdAt);
    return diff.inDays <= 7;
  }

  // 4. Combined Fluent Languages
  List<String> get allFluentLanguages {
    return [nativeLanguage, ...additionalNativeLanguages];
  }
 String get currentLevel {
    if (currentLanguage.isEmpty) return 'A1 - Newcomer';
    return languageLevels[currentLanguage] ?? 'A1 - Newcomer';
  }
  // --- FACTORY & SERIALIZATION ---

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    // Helper for Dates
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }
    
    // Helper for Nullable Dates
    DateTime? parseNullableDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    // Helper for Lists
    List<String> parseList(String key) {
      return (map[key] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    }

    return UserModel(
      id: id,
      email: map['email']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? '',
      photoUrl: map['photoUrl']?.toString(),
      username: map['username']?.toString(),
      bio: map['bio']?.toString(),
      isVerified: map['isVerified'] == true,
      
      birthDate: parseNullableDate(map['birthDate']),
      gender: map['gender']?.toString(),
      city: map['city']?.toString(),
      country: map['country']?.toString(),
      countryCode: map['countryCode']?.toString(),
      location: map['location'] as GeoPoint?,

      nativeLanguage: map['nativeLanguage']?.toString() ?? 'en',
      additionalNativeLanguages: parseList('additionalNativeLanguages'),
      currentLanguage: map['currentLanguage']?.toString() ?? '',
      targetLanguages: parseList('targetLanguages'),
      languageLevels: (map['languageLevels'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value.toString()),
          ) ?? {},
      completedLevels: parseList('completedLevels'),

      topics: parseList('topics'),
      learningGoal: map['learningGoal']?.toString(),
      correctionStyle: map['correctionStyle']?.toString() ?? 'gentle',
      communicationStyles: parseList('communicationStyles'),
      
      references: (map['references'] as List<dynamic>?)
          ?.map((x) => UserReference.fromMap(x as Map<String, dynamic>))
          .toList() ?? [],

      isOnline: map['isOnline'] == true,
      lastActiveAt: parseNullableDate(map['lastActiveAt']),
      friends: parseList('friends'),
      following: parseList('following'),
      followers: parseList('followers'),
      blockedUsers: parseList('blockedUsers'),

      xp: (map['xp'] as num?)?.toInt() ?? 0,
      streakDays: (map['streakDays'] as num?)?.toInt() ?? 0,
      lastLoginDate: parseNullableDate(map['lastLoginDate']),
      lessonsCompleted: (map['lessonsCompleted'] as num?)?.toInt() ?? 0,
      totalListeningMinutes: (map['totalListeningMinutes'] as num?)?.toInt() ?? 0,
      dailyGoalMinutes: (map['dailyGoalMinutes'] as num?)?.toInt() ?? 15,
      badges: parseList('badges'),

      createdAt: parseDate(map['createdAt']),
      isPremium: map['isPremium'] == true,
      premiumDetails: map['premiumDetails'] != null
          ? Map<String, dynamic>.from(map['premiumDetails'])
          : null,
      searchKeywords: parseList('searchKeywords'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'username': username,
      'bio': bio,
      'isVerified': isVerified,
      'birthDate': birthDate != null ? Timestamp.fromDate(birthDate!) : null,
      'gender': gender,
      'city': city,
      'country': country,
      'countryCode': countryCode,
      'location': location, // GeoPoint writes directly
      'nativeLanguage': nativeLanguage,
      'additionalNativeLanguages': additionalNativeLanguages,
      'currentLanguage': currentLanguage,
      'targetLanguages': targetLanguages,
      'languageLevels': languageLevels,
      'completedLevels': completedLevels,
      'topics': topics,
      'learningGoal': learningGoal,
      'correctionStyle': correctionStyle,
      'communicationStyles': communicationStyles,
      'references': references.map((x) => x.toMap()).toList(),
      'isOnline': isOnline,
      'lastActiveAt': lastActiveAt != null ? Timestamp.fromDate(lastActiveAt!) : null,
      'friends': friends,
      'following': following,
      'followers': followers,
      'blockedUsers': blockedUsers,
      'xp': xp,
      'streakDays': streakDays,
      'lastLoginDate': lastLoginDate != null ? Timestamp.fromDate(lastLoginDate!) : null,
      'lessonsCompleted': lessonsCompleted,
      'totalListeningMinutes': totalListeningMinutes,
      'dailyGoalMinutes': dailyGoalMinutes,
      'badges': badges,
      'createdAt': Timestamp.fromDate(createdAt),
      'isPremium': isPremium,
      'premiumDetails': premiumDetails,
      'searchKeywords': searchKeywords,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    String? username,
    String? bio,
    bool? isVerified,
    DateTime? birthDate,
    String? gender,
    String? city,
    String? country,
    String? countryCode,
    GeoPoint? location,
    String? nativeLanguage,
    List<String>? additionalNativeLanguages,
    String? currentLanguage,
    List<String>? targetLanguages,
    Map<String, String>? languageLevels,
    List<String>? completedLevels,
    List<String>? topics,
    String? learningGoal,
    String? correctionStyle,
    List<String>? communicationStyles,
    List<UserReference>? references,
    bool? isOnline,
    DateTime? lastActiveAt,
    List<String>? friends,
    List<String>? following,
    List<String>? followers,
    List<String>? blockedUsers,
    int? xp,
    int? streakDays,
    DateTime? lastLoginDate,
    int? lessonsCompleted,
    int? totalListeningMinutes,
    int? dailyGoalMinutes,
    List<String>? badges,
    DateTime? createdAt,
    bool? isPremium,
    Map<String, dynamic>? premiumDetails,
    List<String>? searchKeywords,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      isVerified: isVerified ?? this.isVerified,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      city: city ?? this.city,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      location: location ?? this.location,
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      additionalNativeLanguages: additionalNativeLanguages ?? this.additionalNativeLanguages,
      currentLanguage: currentLanguage ?? this.currentLanguage,
      targetLanguages: targetLanguages ?? this.targetLanguages,
      languageLevels: languageLevels ?? this.languageLevels,
      completedLevels: completedLevels ?? this.completedLevels,
      topics: topics ?? this.topics,
      learningGoal: learningGoal ?? this.learningGoal,
      correctionStyle: correctionStyle ?? this.correctionStyle,
      communicationStyles: communicationStyles ?? this.communicationStyles,
      references: references ?? this.references,
      isOnline: isOnline ?? this.isOnline,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      friends: friends ?? this.friends,
      following: following ?? this.following,
      followers: followers ?? this.followers,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      xp: xp ?? this.xp,
      streakDays: streakDays ?? this.streakDays,
      lastLoginDate: lastLoginDate ?? this.lastLoginDate,
      lessonsCompleted: lessonsCompleted ?? this.lessonsCompleted,
      totalListeningMinutes: totalListeningMinutes ?? this.totalListeningMinutes,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      badges: badges ?? this.badges,
      createdAt: createdAt ?? this.createdAt,
      isPremium: isPremium ?? this.isPremium,
      premiumDetails: premiumDetails ?? this.premiumDetails,
      searchKeywords: searchKeywords ?? this.searchKeywords,
    );
  }
}

// --- HELPER CLASS FOR REFERENCES ---
class UserReference {
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String text;
  final int rating; // 1-5
  final DateTime createdAt;

  UserReference({
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.text,
    required this.rating,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'text': text,
      'rating': rating,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UserReference.fromMap(Map<String, dynamic> map) {
    return UserReference(
      authorId: map['authorId']?.toString() ?? '',
      authorName: map['authorName']?.toString() ?? 'Unknown',
      authorPhotoUrl: map['authorPhotoUrl']?.toString(),
      text: map['text']?.toString() ?? '',
      rating: (map['rating'] as num?)?.toInt() ?? 5,
      createdAt: map['createdAt'] is Timestamp 
          ? (map['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }
}