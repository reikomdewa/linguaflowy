

part of 'quiz_bloc.dart';

abstract class QuizEvent {
  const QuizEvent();
}
class QuizStartWithQuestions extends QuizEvent {
  final List<dynamic> questions;
  final String userId;
  final bool isPremium;

  const QuizStartWithQuestions({
    required this.questions,
    required this.userId,
    required this.isPremium,
  });
}
class QuizLoadRequested extends QuizEvent {
  final String targetLanguage;
  final String nativeLanguage;
  final QuizPromptType promptType;
  final String? topic;
  final bool isPremium;
  final String userId; // <--- ADD THIS FIELD

  const QuizLoadRequested({
    required this.userId, // <--- ADD TO CONSTRUCTOR
    required this.targetLanguage,
    required this.nativeLanguage,
    required this.promptType,
    required this.isPremium,
    this.topic,
  });
}

// ... (keep your other events like QuizOptionSelected, etc. the same)
class QuizOptionSelected extends QuizEvent {
  final String word;
  const QuizOptionSelected(this.word);
}
class QuizOptionDeselected extends QuizEvent {
  final String word;
  const QuizOptionDeselected(this.word);
}
class QuizCheckAnswer extends QuizEvent { const QuizCheckAnswer(); }
class QuizNextQuestion extends QuizEvent { const QuizNextQuestion(); }
class QuizReviveRequested extends QuizEvent { const QuizReviveRequested(); }