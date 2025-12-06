// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:linguaflow/models/quiz_model.dart'; // <--- CRITICAL IMPORT
// import 'package:linguaflow/services/quiz_service.dart';

// part 'quiz_event.dart';
// part 'quiz_state.dart';

// class QuizBloc extends Bloc<QuizEvent, QuizState> {
//   final QuizService _quizService = QuizService();

//   QuizBloc() : super(const QuizState()) {
//     on<QuizLoadRequested>(_onLoadRequested);
//     on<QuizOptionSelected>(_onOptionSelected);
//     on<QuizOptionDeselected>(_onOptionDeselected);
//     on<QuizCheckAnswer>(_onCheckAnswer);
//     on<QuizNextQuestion>(_onNextQuestion);
//     on<QuizReviveRequested>(_onReviveRequested);
//   }

//   // 1. LOAD QUESTIONS
//   Future<void> _onLoadRequested(QuizLoadRequested event, Emitter<QuizState> emit) async {
//     emit(state.copyWith(status: QuizStatus.loading));

//     try {
//       final questions = await _quizService.generateQuiz(
//         targetLanguage: event.targetLanguage,
//         nativeLanguage: event.nativeLanguage,
//         type: event.promptType,
//         topic: event.topic,
//         userId: 
//       );

//       if (questions.isEmpty) throw Exception("No questions generated");

//       final firstQ = questions[0];
//       final initialOptions = List<String>.from(firstQ.options)..shuffle();

//       emit(state.copyWith(
//         status: QuizStatus.answering,
//         questions: questions,
//         currentIndex: 0,
//         selectedWords: [],
//         availableWords: initialOptions,
//         hearts: 5,
//         isPremium: event.isPremium,
//         correctAnswersCount: 0,
//       ));

//     } catch (e) {
//       print("Quiz Bloc Error: $e");
//       emit(state.copyWith(
//         status: QuizStatus.error, 
//         errorMessage: "Failed to load quiz. Please try again."
//       ));
//     }
//   }

//   // 2. SELECT WORD
//   void _onOptionSelected(QuizOptionSelected event, Emitter<QuizState> emit) {
//     if (state.status != QuizStatus.answering) return;
//     final newSelected = List<String>.from(state.selectedWords)..add(event.word);
//     final newAvailable = List<String>.from(state.availableWords)..remove(event.word);
//     emit(state.copyWith(selectedWords: newSelected, availableWords: newAvailable));
//   }

//   // 3. DESELECT WORD
//   void _onOptionDeselected(QuizOptionDeselected event, Emitter<QuizState> emit) {
//     if (state.status != QuizStatus.answering) return;
//     final newSelected = List<String>.from(state.selectedWords)..remove(event.word);
//     final newAvailable = List<String>.from(state.availableWords)..add(event.word);
//     emit(state.copyWith(selectedWords: newSelected, availableWords: newAvailable));
//   }

//   // 4. CHECK ANSWER
//   void _onCheckAnswer(QuizCheckAnswer event, Emitter<QuizState> emit) {
//     final currentQ = state.currentQuestion;
//     if (currentQ == null) return;

//     final userSentence = state.selectedWords.join(" ");
    
//     // Normalize string for comparison (remove punctuation, lowercase)
//     final cleanUser = userSentence.trim().toLowerCase().replaceAll(RegExp(r'[^\w\s\u00C0-\u017F]'), '');
//     final cleanCorrect = currentQ.correctAnswer.trim().toLowerCase().replaceAll(RegExp(r'[^\w\s\u00C0-\u017F]'), '');

//     if (cleanUser == cleanCorrect) {
//       emit(state.copyWith(
//         status: QuizStatus.correct,
//         correctAnswersCount: state.correctAnswersCount + 1,
//       ));
//     } else {
//       int newHearts = state.hearts;
//       if (!state.isPremium) {
//         newHearts = state.hearts - 1;
//       }
//       emit(state.copyWith(
//         status: QuizStatus.incorrect, 
//         hearts: newHearts < 0 ? 0 : newHearts
//       ));
//     }
//   }

//   // 5. NEXT QUESTION
//   void _onNextQuestion(QuizNextQuestion event, Emitter<QuizState> emit) {
//     if (!state.isPremium && state.hearts <= 0) return;

//     final nextIndex = state.currentIndex + 1;

//     if (nextIndex >= state.questions.length) {
//       emit(state.copyWith(status: QuizStatus.completed));
//     } else {
//       final nextQ = state.questions[nextIndex];
//       final nextOptions = List<String>.from(nextQ.options)..shuffle();

//       emit(state.copyWith(
//         status: QuizStatus.answering,
//         currentIndex: nextIndex,
//         selectedWords: [],
//         availableWords: nextOptions,
//       ));
//     }
//   }

//   // 6. REVIVE
//   void _onReviveRequested(QuizReviveRequested event, Emitter<QuizState> emit) {
//     emit(state.copyWith(hearts: 5, isPremium: true));
//   }
// }



import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/models/quiz_model.dart'; 
import 'package:linguaflow/services/quiz_service.dart';

part 'quiz_event.dart';
part 'quiz_state.dart';

class QuizBloc extends Bloc<QuizEvent, QuizState> {
  final QuizService _quizService = QuizService();

  QuizBloc() : super(const QuizState()) {
    on<QuizLoadRequested>(_onLoadRequested);
    on<QuizOptionSelected>(_onOptionSelected);
    on<QuizOptionDeselected>(_onOptionDeselected);
    on<QuizCheckAnswer>(_onCheckAnswer);
    on<QuizNextQuestion>(_onNextQuestion);
    on<QuizReviveRequested>(_onReviveRequested);
  }

  // 1. LOAD QUESTIONS
  Future<void> _onLoadRequested(QuizLoadRequested event, Emitter<QuizState> emit) async {
    emit(state.copyWith(status: QuizStatus.loading));

    try {
      final questions = await _quizService.generateQuiz(
        userId: event.userId, // <--- FIXED: Get the ID from the event
        targetLanguage: event.targetLanguage,
        nativeLanguage: event.nativeLanguage,
        type: event.promptType,
        topic: event.topic,
      );

      if (questions.isEmpty) throw Exception("No questions generated");

      final firstQ = questions[0];
      final initialOptions = List<String>.from(firstQ.options)..shuffle();

      emit(state.copyWith(
        status: QuizStatus.answering,
        questions: questions,
        currentIndex: 0,
        selectedWords: [],
        availableWords: initialOptions,
        hearts: 5,
        isPremium: event.isPremium,
        correctAnswersCount: 0,
      ));

    } catch (e) {
      print("Quiz Bloc Error: $e");
      emit(state.copyWith(
        status: QuizStatus.error, 
        errorMessage: "Failed to load quiz. Please try again."
      ));
    }
  }

  // ... (Rest of your methods remain exactly the same)
  void _onOptionSelected(QuizOptionSelected event, Emitter<QuizState> emit) {
    if (state.status != QuizStatus.answering) return;
    final newSelected = List<String>.from(state.selectedWords)..add(event.word);
    final newAvailable = List<String>.from(state.availableWords)..remove(event.word);
    emit(state.copyWith(selectedWords: newSelected, availableWords: newAvailable));
  }

  void _onOptionDeselected(QuizOptionDeselected event, Emitter<QuizState> emit) {
    if (state.status != QuizStatus.answering) return;
    final newSelected = List<String>.from(state.selectedWords)..remove(event.word);
    final newAvailable = List<String>.from(state.availableWords)..add(event.word);
    emit(state.copyWith(selectedWords: newSelected, availableWords: newAvailable));
  }

  void _onCheckAnswer(QuizCheckAnswer event, Emitter<QuizState> emit) {
    final currentQ = state.currentQuestion;
    if (currentQ == null) return;

    final userSentence = state.selectedWords.join(" ");
    
    final cleanUser = userSentence.trim().toLowerCase().replaceAll(RegExp(r'[^\w\s\u00C0-\u017F]'), '');
    final cleanCorrect = currentQ.correctAnswer.trim().toLowerCase().replaceAll(RegExp(r'[^\w\s\u00C0-\u017F]'), '');

    if (cleanUser == cleanCorrect) {
      emit(state.copyWith(
        status: QuizStatus.correct,
        correctAnswersCount: state.correctAnswersCount + 1,
      ));
    } else {
      int newHearts = state.hearts;
      if (!state.isPremium) {
        newHearts = state.hearts - 1;
      }
      emit(state.copyWith(
        status: QuizStatus.incorrect, 
        hearts: newHearts < 0 ? 0 : newHearts
      ));
    }
  }

  void _onNextQuestion(QuizNextQuestion event, Emitter<QuizState> emit) {
    if (!state.isPremium && state.hearts <= 0) return;

    final nextIndex = state.currentIndex + 1;

    if (nextIndex >= state.questions.length) {
      emit(state.copyWith(status: QuizStatus.completed));
    } else {
      final nextQ = state.questions[nextIndex];
      final nextOptions = List<String>.from(nextQ.options)..shuffle();

      emit(state.copyWith(
        status: QuizStatus.answering,
        currentIndex: nextIndex,
        selectedWords: [],
        availableWords: nextOptions,
      ));
    }
  }

  void _onReviveRequested(QuizReviveRequested event, Emitter<QuizState> emit) {
    emit(state.copyWith(hearts: 5, isPremium: true));
  }
}