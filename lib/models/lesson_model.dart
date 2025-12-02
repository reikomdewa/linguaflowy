
// ==========================================
// DATA MODELS
// ==========================================
// File: lib/models/user_model.dart

class UserModel {
  final String id;
  final String email;
  final String displayName;
  final String nativeLanguage;
  final List<String> targetLanguages;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.nativeLanguage = 'en',
    this.targetLanguages = const [],
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      nativeLanguage: map['nativeLanguage'] ?? 'en',
      targetLanguages: List<String>.from(map['targetLanguages'] ?? []),
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'nativeLanguage': nativeLanguage,
      'targetLanguages': targetLanguages,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

// File: lib/models/lesson_model.dart

class LessonModel {
  final String id;
  final String userId;
  final String title;
  final String language;
  final String content;
  final List<String> sentences;
  final DateTime createdAt;
  final int progress;

  var imageUrl;

  var isFavorite;

  LessonModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.language,
    required this.content,
    required this.sentences,
    required this.createdAt,
    this.progress = 0, required bool isFavorite,
  });

  factory LessonModel.fromMap(Map<String, dynamic> map, String id) {
    return LessonModel(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      language: map['language'] ?? '',
      content: map['content'] ?? '',
      sentences: List<String>.from(map['sentences'] ?? []),
      createdAt: DateTime.parse(map['createdAt']),
      progress: map['progress'] ?? 0,
       isFavorite: false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'language': language,
      'content': content,
      'sentences': sentences,
      'createdAt': createdAt.toIso8601String(),
      'progress': progress,
    };
  }
}
