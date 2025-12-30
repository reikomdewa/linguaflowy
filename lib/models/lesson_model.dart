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
  
  // --- CORE TYPES ---
  final String type; // 'text', 'video', 'audio'
  final String originality; // 'ai_story', 'original', 'graded'
  final String difficulty; // 'A1', 'B2', etc.
  final String genre;
  
  // --- METADATA ---
  final List<String> tags;
  final String source; // 'youtube', 'ai', 'import', 'system'
  final Map<String, dynamic> metadata;

  // --- OWNERSHIP & COMMUNITY ---
  final String? originalAuthorId;
  final bool isPublic;
  final int likes;
  final int views;

  // --- SERIES INFO ---
  final String? seriesId;
  final String? seriesTitle;
  final int? seriesIndex;

  // --- MEDIA ---
  final String? videoUrl;
  final String? subtitleUrl;

  // --- INTERNAL STATE ---
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
    
    // Default to 'original' if not specified
    this.originality = 'original', 
    
    this.difficulty = 'intermediate',
    this.genre = 'general',
    this.originalAuthorId,

    // --- NEW FIELDS ---
    this.isPublic = false,
    this.tags = const [],
    this.likes = 0,
    this.views = 0,
    
    // Default to 'system' ONLY if not specified
    this.source = 'system', 
    
    this.metadata = const {},
    this.seriesId,
    this.seriesTitle,
    this.seriesIndex,
    this.videoUrl,
    this.subtitleUrl,
    this.isLocal = false,
  });

  String? get mediaUrl => videoUrl;

  bool get isOriginal => originalAuthorId == null || userId == originalAuthorId;

  // --- FROM MAP (Firestore -> App) ---
  factory LessonModel.fromMap(Map<String, dynamic> map, String id) {
    return LessonModel(
      id: id,
      userId: map['userId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      language: map['language']?.toString() ?? 'en',
      content: map['content']?.toString() ?? '',
      
      // Lists
      sentences: (map['sentences'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [],
      transcript: (map['transcript'] as List<dynamic>?)
              ?.map((e) => TranscriptLine.fromMap(e))
              .toList() ?? [],
      tags: (map['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [],

      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
          
      progress: int.tryParse(map['progress'].toString()) ?? 0,
      imageUrl: map['imageUrl']?.toString(),
      isFavorite: map['isFavorite'] == true,
      
      // Core fields
      type: map['type']?.toString() ?? 'text',
      originality: map['originality']?.toString() ?? 'original', // <--- LOAD IT
      difficulty: map['difficulty']?.toString() ?? 'intermediate',
      genre: map['genre']?.toString() ?? 'general',
      source: map['source']?.toString() ?? 'system', // <--- LOAD IT
      
      originalAuthorId: map['originalAuthorId']?.toString(),
      isPublic: map['isPublic'] == true,
      likes: int.tryParse(map['likes']?.toString() ?? '0') ?? 0,
      views: int.tryParse(map['views']?.toString() ?? '0') ?? 0,
      
      metadata: map['metadata'] is Map<String, dynamic>
          ? map['metadata'] as Map<String, dynamic>
          : {},

      seriesId: map['seriesId']?.toString(),
      seriesTitle: map['seriesTitle']?.toString(),
      seriesIndex: int.tryParse(map['seriesIndex']?.toString() ?? ''),

      videoUrl: map['videoUrl']?.toString(),
      subtitleUrl: map['subtitleUrl']?.toString(),
      
      isLocal: false,
    );
  }

  // --- TO MAP (App -> Firestore) ---
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
      
      // Critical Fields
      'type': type,
      'originality': originality, // <--- SAVE IT
      'difficulty': difficulty,
      'genre': genre,
      'source': source, // <--- SAVE IT
      
      'originalAuthorId': originalAuthorId,
      'isPublic': isPublic,
      'tags': tags,
      'likes': likes,
      'views': views,
      'metadata': metadata,

      'seriesId': seriesId,
      'seriesTitle': seriesTitle,
      'seriesIndex': seriesIndex,
      'videoUrl': videoUrl,
      'subtitleUrl': subtitleUrl,
    };
  }

  // --- COPY WITH (For Updates) ---
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
    String? originality, // <--- ALLOW UPDATE
    String? difficulty,
    String? genre,
    String? originalAuthorId,
    bool? isPublic,
    List<String>? tags,
    int? likes,
    int? views,
    String? source, // <--- ALLOW UPDATE
    Map<String, dynamic>? metadata,
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
      
      // Ensure these propagate correctly
      originality: originality ?? this.originality, 
      difficulty: difficulty ?? this.difficulty,
      genre: genre ?? this.genre,
      source: source ?? this.source,
      
      originalAuthorId: originalAuthorId ?? this.originalAuthorId,
      isPublic: isPublic ?? this.isPublic,
      tags: tags ?? this.tags,
      likes: likes ?? this.likes,
      views: views ?? this.views,
      metadata: metadata ?? this.metadata,
      
      seriesId: seriesId ?? this.seriesId,
      seriesTitle: seriesTitle ?? this.seriesTitle,
      seriesIndex: seriesIndex ?? this.seriesIndex,
      videoUrl: videoUrl ?? this.videoUrl,
      subtitleUrl: subtitleUrl ?? this.subtitleUrl,
      isLocal: isLocal ?? this.isLocal,
    );
  }

  /// Merges fresh system data into user progress
  LessonModel mergeSystemData(LessonModel systemLesson) {
    return copyWith(
      // Keep User Progress
      progress: progress,
      isFavorite: isFavorite,
      createdAt: createdAt,

      // Update System Data
      title: systemLesson.title,
      content: systemLesson.content,
      imageUrl: systemLesson.imageUrl,
      videoUrl: systemLesson.videoUrl,
      sentences: systemLesson.sentences,
      transcript: systemLesson.transcript,
      seriesId: systemLesson.seriesId,
      seriesTitle: systemLesson.seriesTitle,
      seriesIndex: systemLesson.seriesIndex,
      difficulty: systemLesson.difficulty,
      genre: systemLesson.genre,
      
      // Ensure these update too
      originality: systemLesson.originality, 
      tags: systemLesson.tags,
      source: systemLesson.source,
      metadata: systemLesson.metadata,
    );
  }
}