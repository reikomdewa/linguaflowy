import 'package:cloud_firestore/cloud_firestore.dart';

class VocabularyItem {
  final String id;
  final String userId;
  final String word;
  final String baseForm;
  final String language;
  final String translation;
  final int status;
  final int timesEncountered;
  final DateTime lastReviewed;
  final DateTime createdAt;
  final String? notes;

  // --- NEW FIELDS FOR VIDEO SRS ---
  final String? sourceVideoUrl;
  final double? timestamp; // Seconds
  final String? sentenceContext;

  VocabularyItem({
    required this.id,
    required this.userId,
    required this.word,
    required this.baseForm,
    required this.language,
    required this.translation,
    this.status = 0,
    this.timesEncountered = 1,
    required this.lastReviewed,
    required this.createdAt,
    this.notes,
    this.sourceVideoUrl,
    this.timestamp,
    this.sentenceContext,
  });

  // *** ROBUST COPYWITH ***
  VocabularyItem copyWith({
    String? id,
    String? userId,
    String? word,
    String? baseForm,
    String? language,
    String? translation,
    int? status,
    int? timesEncountered,
    DateTime? lastReviewed,
    DateTime? createdAt,
    String? notes,
    String? sourceVideoUrl,
    double? timestamp,
    String? sentenceContext,
  }) {
    return VocabularyItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      word: word ?? this.word,
      baseForm: baseForm ?? this.baseForm,
      language: language ?? this.language,
      translation: translation ?? this.translation,
      status: status ?? this.status,
      timesEncountered: timesEncountered ?? this.timesEncountered,
      lastReviewed: lastReviewed ?? this.lastReviewed,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
      sourceVideoUrl: sourceVideoUrl ?? this.sourceVideoUrl,
      timestamp: timestamp ?? this.timestamp,
      sentenceContext: sentenceContext ?? this.sentenceContext,
    );
  }

  // *** ROBUST FROMMAP ***
  factory VocabularyItem.fromMap(Map<String, dynamic> map, String id) {
    
    // Internal helper to parse dates safely
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate(); // Handles Firestore format
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now(); // Handles ISO String
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return DateTime.now();
    }

    // Helper to safely parse doubles (for timestamps)
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    return VocabularyItem(
      id: id,
      userId: map['userId']?.toString() ?? '',
      word: map['word']?.toString() ?? '',
      baseForm: map['baseForm']?.toString() ?? '',
      language: map['language']?.toString() ?? '',
      translation: map['translation']?.toString() ?? '',
      // Safely parse integers
      status: (map['status'] is int) 
          ? map['status'] 
          : int.tryParse(map['status']?.toString() ?? '0') ?? 0,
      timesEncountered: (map['timesEncountered'] is int) 
          ? map['timesEncountered'] 
          : int.tryParse(map['timesEncountered']?.toString() ?? '1') ?? 1,
      // Use the safe date parser
      lastReviewed: parseDate(map['lastReviewed']),
      createdAt: parseDate(map['createdAt']),
      notes: map['notes']?.toString(),
      // New Video SRS fields
      sourceVideoUrl: map['sourceVideoUrl']?.toString(),
      timestamp: parseDouble(map['timestamp']),
      sentenceContext: map['sentenceContext']?.toString(),
    );
  }

  // *** ROBUST TOMAP ***
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'word': word,
      'baseForm': baseForm,
      'language': language,
      'translation': translation,
      'status': status,
      'timesEncountered': timesEncountered,
      'lastReviewed': Timestamp.fromDate(lastReviewed),
      'createdAt': Timestamp.fromDate(createdAt),
      'notes': notes,
      // New Video SRS fields
      'sourceVideoUrl': sourceVideoUrl,
      'timestamp': timestamp,
      'sentenceContext': sentenceContext,
    };
  }
}