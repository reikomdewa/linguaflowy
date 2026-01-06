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
    // This connects the event to the function
    on<QuizStartWithQuestions>(_onQuizStartWithQuestions);
  }

  // 1. LOAD QUESTIONS (AI GENERATED)
  Future<void> _onLoadRequested(
    QuizLoadRequested event,
    Emitter<QuizState> emit,
  ) async {
    if (state.status == QuizStatus.loading) {
      print("QuizBloc: Already loading. Ignoring duplicate request.");
      return;
    }

    emit(state.copyWith(status: QuizStatus.loading));

    try {
      final questions = await _quizService.generateQuiz(
        userId: event.userId,
        targetLanguage: event.targetLanguage,
        nativeLanguage: event.nativeLanguage,
        type: event.promptType,
        topic: event.topic,
      );

      if (questions.isEmpty) throw Exception("No questions generated");

      final firstQ = questions[0];
      final initialOptions = List<String>.from(firstQ.options)..shuffle();

      emit(
        state.copyWith(
          status: QuizStatus.answering,
          questions: questions,
          currentIndex: 0,
          selectedWords: [],
          availableWords: initialOptions,
          hearts: 5,
          isPremium: event.isPremium,
          correctAnswersCount: 0,
        ),
      );
    } catch (e) {
      print("Quiz Bloc Error: $e");
      emit(
        state.copyWith(
          status: QuizStatus.error,
          errorMessage:
              "Server is busy (429). Please wait a moment and try again.",
        ),
      );
    }
  }

  // 2. LOAD PRE-DEFINED QUESTIONS (FROM UNIT SELECTION)
  // --- THIS IS THE NEW PART ---
  void _onQuizStartWithQuestions(
    QuizStartWithQuestions event,
    Emitter<QuizState> emit,
  ) {
    try {
      // Convert raw Map/JSON to Model objects
      final List<QuizQuestion> parsedQuestions = event.questions
          .map((q) => QuizQuestion.fromMap(q as Map<String, dynamic>))
          .toList();

      if (parsedQuestions.isEmpty) {
        emit(
          state.copyWith(
            status: QuizStatus.error,
            errorMessage: "This unit has no valid questions.",
          ),
        );
        return;
      }

      // Prepare the first question
      final firstQ = parsedQuestions[0];
      final initialOptions = List<String>.from(firstQ.options)..shuffle();

      // Emit ready state immediately
      emit(
        state.copyWith(
          status: QuizStatus.answering,
          questions: parsedQuestions,
          currentIndex: 0,
          selectedWords: [],
          availableWords: initialOptions,
          hearts: 5,
          isPremium: event.isPremium,
          correctAnswersCount: 0,
          errorMessage: null, // Clear any previous errors
        ),
      );
    } catch (e) {
      print("Error parsing unit questions: $e");
      emit(
        state.copyWith(
          status: QuizStatus.error,
          errorMessage: "Failed to load unit data.",
        ),
      );
    }
  }

  // 3. GAME LOGIC HANDLERS
  void _onOptionSelected(QuizOptionSelected event, Emitter<QuizState> emit) {
    if (state.status != QuizStatus.answering) return;
    final newSelected = List<String>.from(state.selectedWords)..add(event.word);
    final newAvailable = List<String>.from(state.availableWords)
      ..remove(event.word);
    emit(
      state.copyWith(selectedWords: newSelected, availableWords: newAvailable),
    );
  }

  void _onOptionDeselected(
    QuizOptionDeselected event,
    Emitter<QuizState> emit,
  ) {
    if (state.status != QuizStatus.answering) return;
    final newSelected = List<String>.from(state.selectedWords)
      ..remove(event.word);
    final newAvailable = List<String>.from(state.availableWords)
      ..add(event.word);
    emit(
      state.copyWith(selectedWords: newSelected, availableWords: newAvailable),
    );
  }

  void _onCheckAnswer(QuizCheckAnswer event, Emitter<QuizState> emit) {
    final currentQ = state.currentQuestion;
    if (currentQ == null) return;

    final userSentence = state.selectedWords.join(" ");

    // Normalize strings to ignore punctuation/case differences
    final cleanUser = userSentence.trim().toLowerCase().replaceAll(
      RegExp(r'[^\w\s\u00C0-\u017F]'),
      '',
    );
    final cleanCorrect = currentQ.correctAnswer.trim().toLowerCase().replaceAll(
      RegExp(r'[^\w\s\u00C0-\u017F]'),
      '',
    );

    if (cleanUser == cleanCorrect) {
      emit(
        state.copyWith(
          status: QuizStatus.correct,
          correctAnswersCount: state.correctAnswersCount + 1,
        ),
      );
    } else {
      int newHearts = state.hearts;
      if (!state.isPremium) {
        newHearts = state.hearts - 1;
      }
      emit(
        state.copyWith(
          status: QuizStatus.incorrect,
          hearts: newHearts < 0 ? 0 : newHearts,
        ),
      );
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

      emit(
        state.copyWith(
          status: QuizStatus.answering,
          currentIndex: nextIndex,
          selectedWords: [],
          availableWords: nextOptions,
        ),
      );
    }
  }

  void _onReviveRequested(QuizReviveRequested event, Emitter<QuizState> emit) {
    emit(state.copyWith(hearts: 5, isPremium: true));
  }
}
