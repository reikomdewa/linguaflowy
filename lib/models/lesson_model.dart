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
  final String type; // 'text', 'video', 'audio', 'ai_story'
  final String difficulty; // 'A1', 'B2', etc.
  
  // --- FILTERS & METADATA ---
  final String genre; 
  final List<String> tags; // Future-proof: Better than just genre

  // --- OWNERSHIP & COMMUNITY ---
  final String? originalAuthorId;
  final bool isPublic;      // <--- ADDED: For community sharing
  final int likes;          // <--- ADDED: For community ranking
  final int views;          // <--- ADDED: For popularity
  final String source;      // <--- ADDED: 'youtube', 'ai', 'import', 'system'

  // --- SERIES / PLAYLIST INFO ---
  final String? seriesId;      
  final String? seriesTitle;   
  final int? seriesIndex;      

  // --- MEDIA FIELDS ---
  final String? videoUrl;
  final String? subtitleUrl;

  // --- FLEXIBLE STORAGE (The ultimate future-proofer) ---
  // Store AI prompts, YouTube channel names, specific dialects, etc.
  // without changing the database schema.
  final Map<String, dynamic> metadata; 

  // --- INTERNAL STATE (Not saved to DB usually) ---
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
    
    // --- NEW FIELDS (With Defaults) ---
    this.isPublic = false,
    this.tags = const [],
    this.likes = 0,
    this.views = 0,
    this.source = 'system', // Default source
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
      isPublic: map['isPublic'] == true,
      tags: (map['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      likes: int.tryParse(map['likes']?.toString() ?? '0') ?? 0,
      views: int.tryParse(map['views']?.toString() ?? '0') ?? 0,
      source: map['source']?.toString() ?? 'system',
      metadata: map['metadata'] is Map<String, dynamic> 
          ? map['metadata'] as Map<String, dynamic> 
          : {},

      // --- SERIES ---
      seriesId: map['seriesId']?.toString(),
      seriesTitle: map['seriesTitle']?.toString(),
      seriesIndex: int.tryParse(map['seriesIndex']?.toString() ?? ''),

      // --- MEDIA ---
      videoUrl: map['videoUrl']?.toString(),
      subtitleUrl: map['subtitleUrl']?.toString(),
      
      // Note: isLocal is usually NOT mapped from DB, defaults to false for cloud items
      isLocal: false, 
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
      'isPublic': isPublic,
      'tags': tags,
      'likes': likes,
      'views': views,
      'source': source,
      'metadata': metadata,

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
    bool? isPublic,
    List<String>? tags,
    int? likes,
    int? views,
    String? source,
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
      difficulty: difficulty ?? this.difficulty,
      genre: genre ?? this.genre,
      originalAuthorId: originalAuthorId ?? this.originalAuthorId,
      
      // --- COPY LOGIC ---
      isPublic: isPublic ?? this.isPublic,
      tags: tags ?? this.tags,
      likes: likes ?? this.likes,
      views: views ?? this.views,
      source: source ?? this.source,
      metadata: metadata ?? this.metadata,

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
      progress: progress,
      isFavorite: isFavorite,
      createdAt: createdAt,
      
      // Update Content/Metadata from System
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
      
      // Merge new fields
      tags: systemLesson.tags,
      source: systemLesson.source,
      metadata: systemLesson.metadata,
      // Note: We might NOT want to merge isPublic/likes/views if this is a local copy
    );
  }
}