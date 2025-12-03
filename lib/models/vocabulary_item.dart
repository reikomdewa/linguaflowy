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
  });

  // *** ROBUST COPYWITH ***
  // Allows you to update specific fields while keeping the rest unchanged.
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
    );
  }

  // *** ROBUST FROMMAP ***
  // Handles Timestamps (Firestore), Strings (JSON), and Nulls safely.
  factory VocabularyItem.fromMap(Map<String, dynamic> map, String id) {
    
    // Internal helper to parse dates safely
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate(); // Handles Firestore format
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now(); // Handles ISO String
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return DateTime.now();
    }

    return VocabularyItem(
      id: id,
      // .toString() prevents crashes if a number gets saved into a text field
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
    );
  }

  // *** ROBUST TOMAP ***
  // Saves dates as Timestamps for Firestore (cleaner database types)
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'word': word,
      'baseForm': baseForm,
      'language': language,
      'translation': translation,
      'status': status,
      'timesEncountered': timesEncountered,
      // Convert DateTime to Firestore Timestamp
      'lastReviewed': Timestamp.fromDate(lastReviewed),
      'createdAt': Timestamp.fromDate(createdAt),
      'notes': notes,
    };
  }
}