class QuizQuestion {
  final String id;
  final String type; // 'target_to_native' or 'native_to_target'
  final String targetSentence; // The sentence shown to the user
  final String correctAnswer;  // The answer the user must build
  final List<String> options;  // The word bank (correct words + distractors)

  const QuizQuestion({
    required this.id,
    required this.type,
    required this.targetSentence,
    required this.correctAnswer,
    required this.options,
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
    };
  }

  /// Creates a copy of the object with some fields replaced (Useful for Bloc)
  QuizQuestion copyWith({
    String? id,
    String? type,
    String? targetSentence,
    String? correctAnswer,
    List<String>? options,
  }) {
    return QuizQuestion(
      id: id ?? this.id,
      type: type ?? this.type,
      targetSentence: targetSentence ?? this.targetSentence,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      options: options ?? this.options,
    );
  }
}