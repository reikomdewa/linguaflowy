part of 'quiz_bloc.dart';

enum QuizStatus { initial, loading, answering, correct, incorrect, completed, error }

class QuizState {
  final QuizStatus status;
  final List<QuizQuestion> questions;
  final int currentIndex;
  final int hearts;
  final bool isPremium;
  
  // Word Bank Logic
  final List<String> selectedWords; // Words currently in the sentence line
  final List<String> availableWords; // Words remaining in the bank

  // --- NEW FIELDS ---
  final int correctAnswersCount; // <--- This was missing in your copyWith
  final String? errorMessage;

  // Computed properties
  QuizQuestion? get currentQuestion => 
      (questions.isNotEmpty && currentIndex < questions.length) 
      ? questions[currentIndex] 
      : null;
      
  double get progress => questions.isEmpty ? 0 : (currentIndex / questions.length);

  const QuizState({
    this.status = QuizStatus.initial,
    this.questions = const [],
    this.currentIndex = 0,
    this.hearts = 5,
    this.selectedWords = const [],
    this.availableWords = const [],
    this.isPremium = false,
    this.correctAnswersCount = 0, // Default to 0
    this.errorMessage,
  });

  QuizState copyWith({
    QuizStatus? status,
    List<QuizQuestion>? questions,
    int? currentIndex,
    int? hearts,
    List<String>? selectedWords,
    List<String>? availableWords,
    bool? isPremium,
    int? correctAnswersCount, // <--- Added parameter here
    String? errorMessage,
  }) {
    return QuizState(
      status: status ?? this.status,
      questions: questions ?? this.questions,
      currentIndex: currentIndex ?? this.currentIndex,
      hearts: hearts ?? this.hearts,
      selectedWords: selectedWords ?? this.selectedWords,
      availableWords: availableWords ?? this.availableWords,
      isPremium: isPremium ?? this.isPremium,
      correctAnswersCount: correctAnswersCount ?? this.correctAnswersCount, // <--- Added assignment here
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}