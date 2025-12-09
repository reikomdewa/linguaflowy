class QuizLevel {
  final String id;
  final String topic;     // e.g. "Basics"
  final int unitIndex;    // e.g. 1
  final int questionCount;
  final List<dynamic> questions; // The raw questions list

  QuizLevel({
    required this.id,
    required this.topic,
    required this.unitIndex,
    required this.questionCount,
    required this.questions,
  });

  factory QuizLevel.fromMap(Map<String, dynamic> data) {
    return QuizLevel(
      id: data['id'] ?? '',
      topic: data['topic'] ?? 'Unknown',
      unitIndex: data['unitIndex'] ?? 0,
      questionCount: data['questionCount'] ?? 0,
      questions: data['questions'] ?? [],
    );
  }
}