
// File: lib/models/vocabulary_item.dart

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

  factory VocabularyItem.fromMap(Map<String, dynamic> map, String id) {
    return VocabularyItem(
      id: id,
      userId: map['userId'] ?? '',
      word: map['word'] ?? '',
      baseForm: map['baseForm'] ?? '',
      language: map['language'] ?? '',
      translation: map['translation'] ?? '',
      status: map['status'] ?? 0,
      timesEncountered: map['timesEncountered'] ?? 1,
      lastReviewed: DateTime.parse(map['lastReviewed']),
      createdAt: DateTime.parse(map['createdAt']),
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'word': word,
      'baseForm': baseForm,
      'language': language,
      'translation': translation,
      'status': status,
      'timesEncountered': timesEncountered,
      'lastReviewed': lastReviewed.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'notes': notes,
    };
  }

  VocabularyItem copyWith({
    int? status,
    int? timesEncountered,
    String? translation,
    String? notes, required DateTime lastReviewed,
  }) {
    return VocabularyItem(
      id: id,
      userId: userId,
      word: word,
      baseForm: baseForm,
      language: language,
      translation: translation ?? this.translation,
      status: status ?? this.status,
      timesEncountered: timesEncountered ?? this.timesEncountered,
      lastReviewed: DateTime.now(),
      createdAt: createdAt,
      notes: notes ?? this.notes,
    );
  }
}
