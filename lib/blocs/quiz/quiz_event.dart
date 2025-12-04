part of 'quiz_bloc.dart';

abstract class QuizEvent {}

class QuizLoadRequested extends QuizEvent {
  final String targetLanguage; // e.g., "Spanish"
  final String nativeLanguage; // e.g., "English"
  
  QuizLoadRequested({
    required this.targetLanguage, 
    required this.nativeLanguage
  });
}

class QuizOptionSelected extends QuizEvent {
  final String word;
  QuizOptionSelected(this.word);
}

class QuizOptionDeselected extends QuizEvent {
  final String word;
  QuizOptionDeselected(this.word);
}

class QuizCheckAnswer extends QuizEvent {}

class QuizNextQuestion extends QuizEvent {}