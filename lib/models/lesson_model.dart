import 'package:linguaflow/models/transcript_line.dart';

class LessonModel {
  
  final String id;
  final String userId;
  final String title;
  final String language;
  final String content;
  final List<String> sentences;
  final List<TranscriptLine> transcript;
  final DateTime createdAt;
  final int progress;
  final String? imageUrl;
  final bool isFavorite;
  final String type; // 'text', 'video', 'audio'
  final String difficulty;
  
  // --- FILTERS ---
  final String genre; 

  // --- NEW FIELD FOR OWNERSHIP ---
  final String? originalAuthorId;

  // --- SERIES / PLAYLIST INFO (NEW) ---
  final String? seriesId;      // The YouTube Playlist ID or Book Series ID
  final String? seriesTitle;   // The Name of the Playlist (e.g., "Harry Potter")
  final int? seriesIndex;      // The order (1, 2, 3...)

  // Media Fields
  final String? videoUrl;
  final String? subtitleUrl;

  // Internal State
  final bool isLocal; 

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
    this.genre = 'general',
    this.originalAuthorId,
    
    // --- ADD TO CONSTRUCTOR ---
    this.seriesId,
    this.seriesTitle,
    this.seriesIndex,

    this.videoUrl,
    this.subtitleUrl,
    this.isLocal = false, 
  });

  String? get mediaUrl => videoUrl; 

  bool get isOriginal => originalAuthorId == null || userId == originalAuthorId;

  factory LessonModel.fromMap(Map<String, dynamic> map, String id) {
    return LessonModel(
      id: id,
      userId: map['userId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      language: map['language']?.toString() ?? 'en',
      content: map['content']?.toString() ?? '',
      sentences: (map['sentences'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
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
      genre: map['genre']?.toString() ?? 'general', 
      
      originalAuthorId: map['originalAuthorId']?.toString(),

      // --- MAP NEW FIELDS ---
      seriesId: map['seriesId']?.toString(),
      seriesTitle: map['seriesTitle']?.toString(),
      // Handle parsing safely (string to int)
      seriesIndex: int.tryParse(map['seriesIndex']?.toString() ?? ''),

      videoUrl: map['videoUrl']?.toString(),
      subtitleUrl: map['subtitleUrl']?.toString(),
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
      'genre': genre,
      'originalAuthorId': originalAuthorId, 

      // --- SAVE NEW FIELDS ---
      'seriesId': seriesId,
      'seriesTitle': seriesTitle,
      'seriesIndex': seriesIndex,

      'videoUrl': videoUrl,
      'subtitleUrl': subtitleUrl,
    };
  }

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
    String? genre,
    String? originalAuthorId,
    
    // --- ADD COPY PARAMS ---
    String? seriesId,
    String? seriesTitle,
    int? seriesIndex,

    String? videoUrl,
    String? subtitleUrl,
    bool? isLocal, 
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
      genre: genre ?? this.genre,
      originalAuthorId: originalAuthorId ?? this.originalAuthorId,
      
      // --- COPY LOGIC ---
      seriesId: seriesId ?? this.seriesId,
      seriesTitle: seriesTitle ?? this.seriesTitle,
      seriesIndex: seriesIndex ?? this.seriesIndex,

      videoUrl: videoUrl ?? this.videoUrl,
      subtitleUrl: subtitleUrl ?? this.subtitleUrl,
      isLocal: isLocal ?? this.isLocal, 
    );
  }
  /// Merges fresh system data (metadata) into this user lesson (progress)
  LessonModel mergeSystemData(LessonModel systemLesson) {
    return copyWith(
      // Keep User Progress/State
      progress: this.progress,
      isFavorite: this.isFavorite,
      createdAt: this.createdAt, // Keep user's start date
      
      // Update Content/Metadata from System (The fresh stuff)
      title: systemLesson.title,
      content: systemLesson.content,
      imageUrl: systemLesson.imageUrl,
      videoUrl: systemLesson.videoUrl,
      sentences: systemLesson.sentences,
      transcript: systemLesson.transcript,
      seriesId: systemLesson.seriesId,         // <--- CRITICAL
      seriesTitle: systemLesson.seriesTitle,   // <--- CRITICAL
      seriesIndex: systemLesson.seriesIndex,   // <--- CRITICAL
      difficulty: systemLesson.difficulty,
      genre: systemLesson.genre,
    );
  }
}