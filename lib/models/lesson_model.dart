
// // ==========================================
// // DATA MODELS
// // ==========================================
// // File: lib/models/user_model.dart

// class UserModel {
//   final String id;
//   final String email;
//   final String displayName;
//   final String nativeLanguage;
//   final List<String> targetLanguages;
//   final DateTime createdAt;

//   UserModel({
//     required this.id,
//     required this.email,
//     required this.displayName,
//     this.nativeLanguage = 'en',
//     this.targetLanguages = const [],
//     required this.createdAt,
//   });

//   factory UserModel.fromMap(Map<String, dynamic> map, String id) {
//     return UserModel(
//       id: id,
//       email: map['email'] ?? '',
//       displayName: map['displayName'] ?? '',
//       nativeLanguage: map['nativeLanguage'] ?? 'en',
//       targetLanguages: List<String>.from(map['targetLanguages'] ?? []),
//       createdAt: DateTime.parse(map['createdAt']),
//     );
//   }

//   Map<String, dynamic> toMap() {
//     return {
//       'email': email,
//       'displayName': displayName,
//       'nativeLanguage': nativeLanguage,
//       'targetLanguages': targetLanguages,
//       'createdAt': createdAt.toIso8601String(),
//     };
//   }
// }

// // File: lib/models/lesson_model.dart

// class LessonModel {
//   final String id;
//   final String userId;
//   final String title;
//   final String language;
//   final String content;
//   final List<String> sentences;
//   final DateTime createdAt;
//   final int progress;

//   var imageUrl;

//   var isFavorite;

//   LessonModel({
//     required this.id,
//     required this.userId,
//     required this.title,
//     required this.language,
//     required this.content,
//     required this.sentences,
//     required this.createdAt,
//     this.progress = 0, required bool isFavorite,
//   });

//   factory LessonModel.fromMap(Map<String, dynamic> map, String id) {
//     return LessonModel(
//       id: id,
//       userId: map['userId'] ?? '',
//       title: map['title'] ?? '',
//       language: map['language'] ?? '',
//       content: map['content'] ?? '',
//       sentences: List<String>.from(map['sentences'] ?? []),
//       createdAt: DateTime.parse(map['createdAt']),
//       progress: map['progress'] ?? 0,
//        isFavorite: false,
//     );
//   }

//   Map<String, dynamic> toMap() {
//     return {
//       'userId': userId,
//       'title': title,
//       'language': language,
//       'content': content,
//       'sentences': sentences,
//       'createdAt': createdAt.toIso8601String(),
//       'progress': progress,
//     };
//   }
// }

// class LessonModel {
//   final String id;
//   final String userId;
//   final String title;
//   final String language;
//   final String content;
//   final List<String> sentences;
//   final DateTime createdAt;
//   final int progress;
//   final String? imageUrl;
//   final bool isFavorite;
//   final String type; // 'text', 'video', 'audio'
  
//   // NEW FIELDS
//   final String difficulty; // 'beginner', 'intermediate', 'advanced'
//   final String? videoUrl;

//   LessonModel({
//     required this.id,
//     required this.userId,
//     required this.title,
//     required this.language,
//     required this.content,
//     required this.sentences,
//     required this.createdAt,
//     this.progress = 0,
//     this.imageUrl,
//     this.isFavorite = false,
//     this.type = 'text',
//     this.difficulty = 'intermediate', // Default
//     this.videoUrl,
//   });

//   factory LessonModel.fromMap(Map<String, dynamic> map, String id) {
//     return LessonModel(
//       id: id,
//       userId: map['userId']?.toString() ?? '',
//       title: map['title']?.toString() ?? '',
//       language: map['language']?.toString() ?? 'en',
//       content: map['content']?.toString() ?? '',
//       sentences: (map['sentences'] as List<dynamic>?)
//               ?.map((e) => e.toString())
//               .toList() ?? [],
//       createdAt: map['createdAt'] != null
//           ? DateTime.parse(map['createdAt'].toString())
//           : DateTime.now(),
//       progress: int.tryParse(map['progress'].toString()) ?? 0,
//       imageUrl: map['imageUrl']?.toString(),
//       isFavorite: map['isFavorite'] == true,
//       type: map['type']?.toString() ?? 'text',
//       // Load new fields
//       difficulty: map['difficulty']?.toString() ?? 'intermediate',
//       videoUrl: map['videoUrl']?.toString(),
//     );
//   }

//   Map<String, dynamic> toMap() {
//     return {
//       'userId': userId,
//       'title': title,
//       'language': language,
//       'content': content,
//       'sentences': sentences,
//       'createdAt': createdAt.toIso8601String(),
//       'progress': progress,
//       'imageUrl': imageUrl,
//       'isFavorite': isFavorite,
//       'type': type,
//       'difficulty': difficulty,
//       'videoUrl': videoUrl,
//     };
//   }
// }


import 'package:linguaflow/models/transcript_line.dart';

class LessonModel {
  final String id;
  final String userId;
  final String title;
  final String language;
  final String content;
  final List<String> sentences;
  final List<TranscriptLine> transcript; // New field
  final DateTime createdAt;
  final int progress;
  final String? imageUrl;
  final bool isFavorite;
  final String type; // 'text', 'video', 'audio'
  final String difficulty;
  final String? videoUrl;

  LessonModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.language,
    required this.content,
    this.sentences = const [],
    this.transcript = const [],
    required this.createdAt,
    this.progress = 0,
    this.imageUrl,
    this.isFavorite = false,
    this.type = 'text',
    this.difficulty = 'intermediate',
    this.videoUrl,
  });

  factory LessonModel.fromMap(Map<String, dynamic> map, String id) {
    return LessonModel(
      id: id,
      userId: map['userId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      language: map['language']?.toString() ?? 'en',
      content: map['content']?.toString() ?? '',
      // Handle simple string sentences
      sentences: (map['sentences'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [],
      // Handle structured transcript with timecodes
      transcript: (map['transcript'] as List<dynamic>?)
              ?.map((e) => TranscriptLine.fromMap(e))
              .toList() ?? [],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      progress: int.tryParse(map['progress'].toString()) ?? 0,
      imageUrl: map['imageUrl']?.toString(),
      isFavorite: map['isFavorite'] == true,
      type: map['type']?.toString() ?? 'text',
      difficulty: map['difficulty']?.toString() ?? 'intermediate',
      videoUrl: map['videoUrl']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'language': language,
      'content': content,
      'sentences': sentences,
      'transcript': transcript.map((e) => e.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'progress': progress,
      'imageUrl': imageUrl,
      'isFavorite': isFavorite,
      'type': type,
      'difficulty': difficulty,
      'videoUrl': videoUrl,
    };
  }
}