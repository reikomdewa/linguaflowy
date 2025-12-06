
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
String? get mediaUrl => videoUrl; 
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
              .toList() ??
          [],
      // Handle structured transcript with timecodes
      transcript: (map['transcript'] as List<dynamic>?)
              ?.map((e) => TranscriptLine.fromMap(e))
              .toList() ??
          [],
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

  // --- ADDED THIS METHOD ---
  LessonModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? language,
    String? content,
    List<String>? sentences,
    List<TranscriptLine>? transcript,
    DateTime? createdAt,
    int? progress,
    String? imageUrl,
    bool? isFavorite,
    String? type,
    String? difficulty,
    String? videoUrl,
  }) {
    return LessonModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      language: language ?? this.language,
      content: content ?? this.content,
      sentences: sentences ?? this.sentences,
      transcript: transcript ?? this.transcript,
      createdAt: createdAt ?? this.createdAt,
      progress: progress ?? this.progress,
      imageUrl: imageUrl ?? this.imageUrl,
      isFavorite: isFavorite ?? this.isFavorite,
      type: type ?? this.type,
      difficulty: difficulty ?? this.difficulty,
      videoUrl: videoUrl ?? this.videoUrl,
    );
  }
}