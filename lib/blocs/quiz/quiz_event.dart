part of 'quiz_bloc.dart';

abstract class QuizEvent {}

class QuizLoadRequested extends QuizEvent {
  final String nativeLanguage;
  final String targetLanguage;
  final bool isPremium;
  final QuizPromptType promptType;
  final String? topic;

  QuizLoadRequested({
    required this.nativeLanguage,
    required this.targetLanguage,
    required this.isPremium,
    this.promptType = QuizPromptType.dailyPractice,
    this.topic,
  });
}

class QuizOptionSelected extends QuizEvent { final String word; QuizOptionSelected(this.word); }
class QuizOptionDeselected extends QuizEvent { final String word; QuizOptionDeselected(this.word); }
class QuizCheckAnswer extends QuizEvent {}
class QuizNextQuestion extends QuizEvent {}
class QuizReviveRequested extends QuizEvent {}