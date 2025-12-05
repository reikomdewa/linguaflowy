// class UserModel {
//   final String id;
//   final String email;
//   final String displayName;
//   final String nativeLanguage;
//   final String currentLanguage;
//   final List<String> targetLanguages;
//   final DateTime createdAt;
//   final bool isPremium; // New Field

//   UserModel({
//     required this.id,
//     required this.email,
//     required this.displayName,
//     this.nativeLanguage = 'en',
//     this.currentLanguage = 'es',
//     this.targetLanguages = const [],
//     required this.createdAt,
//     this.isPremium = false, // Default to false
//   });

//   factory UserModel.fromMap(Map<String, dynamic> map, String id) {
//     return UserModel(
//       id: id,
//       email: map['email']?.toString() ?? '',
//       displayName: map['displayName']?.toString() ?? '',
//       nativeLanguage: map['nativeLanguage']?.toString() ?? 'en',
//       currentLanguage: map['currentLanguage']?.toString() ?? 'es',
//       targetLanguages:
//           (map['targetLanguages'] as List<dynamic>?)
//               ?.map((e) => e.toString())
//               .toList() ??
//           [],
//       createdAt: map['createdAt'] != null
//           ? DateTime.parse(map['createdAt'].toString())
//           : DateTime.now(),
//       // Load premium status, default to false if missing
//       isPremium: map['isPremium'] == true, 
//     );
//   }

//   Map<String, dynamic> toMap() {
//     return {
//       'email': email,
//       'displayName': displayName,
//       'nativeLanguage': nativeLanguage,
//       'currentLanguage': currentLanguage,
//       'targetLanguages': targetLanguages,
//       'createdAt': createdAt.toIso8601String(),
//       'isPremium': isPremium, // Save to DB
//     };
//   }

//   // Helper to create a new instance with updated fields
//   UserModel copyWith({
//     String? id,
//     String? email,
//     String? displayName,
//     String? nativeLanguage,
//     String? currentLanguage,
//     List<String>? targetLanguages,
//     DateTime? createdAt,
//     bool? isPremium, // Added parameter
//   }) {
//     return UserModel(
//       id: id ?? this.id,
//       email: email ?? this.email,
//       displayName: displayName ?? this.displayName,
//       nativeLanguage: nativeLanguage ?? this.nativeLanguage,
//       currentLanguage: currentLanguage ?? this.currentLanguage,
//       targetLanguages: targetLanguages ?? this.targetLanguages,
//       createdAt: createdAt ?? this.createdAt,
//       isPremium: isPremium ?? this.isPremium, // Added logic
//     );
//   }
// }


class UserModel {
  final String id;
  final String email;
  final String displayName;
  final String nativeLanguage;
  final String currentLanguage;
  final List<String> targetLanguages;
  final DateTime createdAt;
  final bool isPremium;
  final int xp; // --- NEW FIELD ---

  UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.nativeLanguage = 'en',
    this.currentLanguage = 'es',
    this.targetLanguages = const [],
    required this.createdAt,
    this.isPremium = false,
    this.xp = 0, // --- Default to 0 ---
  });

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
      // --- Load XP (Handle int or double safely, default to 0) ---
      xp: (map['xp'] as num?)?.toInt() ?? 0, 
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
      'xp': xp, // --- Save to DB ---
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
    bool? isPremium,
    int? xp, // --- Added parameter ---
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
      xp: xp ?? this.xp, // --- Update logic ---
    );
  }
}