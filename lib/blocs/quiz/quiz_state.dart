part of 'quiz_bloc.dart';

enum QuizStatus { loading, answering, correct, incorrect, completed }

class QuizState {
  final QuizStatus status;
  final List<QuizQuestion> questions;
  final int currentIndex;
  final int hearts;
   final bool isPremium; 
  
  // Word Bank Logic
  final List<String> selectedWords; // Words currently in the sentence line
  final List<String> availableWords; // Words remaining in the bank

  // Computed properties
  QuizQuestion? get currentQuestion => 
      (questions.isNotEmpty && currentIndex < questions.length) 
      ? questions[currentIndex] 
      : null;
      
  double get progress => questions.isEmpty ? 0 : (currentIndex / questions.length);

  const QuizState({
    this.status = QuizStatus.loading,
    this.questions = const [],
    this.currentIndex = 0,
    this.hearts = 5,
    this.selectedWords = const [],
    this.availableWords = const [],
     this.isPremium = false, 
  });

  QuizState copyWith({
    QuizStatus? status,
    List<QuizQuestion>? questions,
    int? currentIndex,
    int? hearts,
    List<String>? selectedWords,
    List<String>? availableWords,
      bool? isPremium,
  }) {
    return QuizState(
      status: status ?? this.status,
      questions: questions ?? this.questions,
      currentIndex: currentIndex ?? this.currentIndex,
      hearts: hearts ?? this.hearts,
      selectedWords: selectedWords ?? this.selectedWords,
      availableWords: availableWords ?? this.availableWords,
         isPremium: isPremium ?? this.isPremium, 
    );
  }
}