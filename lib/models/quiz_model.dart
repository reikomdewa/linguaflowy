class QuizQuestion {
  final String id;
  final String type; // 'target_to_native' or 'native_to_target'
  final String targetSentence; // The sentence shown to the user
  final String correctAnswer;  // The answer the user must build
  final List<String> options;  // The word bank (correct words + distractors)

  // --- VIDEO CONTEXT ---
  final String? videoUrl;    // URL or ID of the YouTube video
  final double? videoStart;  // Start time in seconds (e.g. 10.5)
  final double? videoEnd;    // End time in seconds (e.g. 14.2)

  const QuizQuestion({
    required this.id,
    required this.type,
    required this.targetSentence,
    required this.correctAnswer,
    required this.options,
    this.videoUrl,
    this.videoStart,
    this.videoEnd,
  });

  /// Factory constructor to create a QuizQuestion from JSON/Firestore data
  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    return QuizQuestion(
      id: map['id']?.toString() ?? '',
      type: map['type']?.toString() ?? 'target_to_native',
      targetSentence: map['targetSentence']?.toString() ?? '',
      correctAnswer: map['correctAnswer']?.toString() ?? '',
      // Safely convert List<dynamic> to List<String>
      options: (map['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      // Video fields
      videoUrl: map['videoUrl']?.toString(),
      videoStart: (map['videoStart'] as num?)?.toDouble(),
      videoEnd: (map['videoEnd'] as num?)?.toDouble(),
    );
  }

  /// Converts the QuizQuestion object back to a Map (useful for uploading)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'targetSentence': targetSentence,
      'correctAnswer': correctAnswer,
      'options': options,
      'videoUrl': videoUrl,
      'videoStart': videoStart,
      'videoEnd': videoEnd,
    };
  }

  /// Creates a copy of the object with some fields replaced (Useful for Bloc)
  QuizQuestion copyWith({
    String? id,
    String? type,
    String? targetSentence,
    String? correctAnswer,
    List<String>? options,
    String? videoUrl,
    double? videoStart,
    double? videoEnd,
  }) {
    return QuizQuestion(
      id: id ?? this.id,
      type: type ?? this.type,
      targetSentence: targetSentence ?? this.targetSentence,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      options: options ?? this.options,
      videoUrl: videoUrl ?? this.videoUrl,
      videoStart: videoStart ?? this.videoStart,
      videoEnd: videoEnd ?? this.videoEnd,
    );
  }
}