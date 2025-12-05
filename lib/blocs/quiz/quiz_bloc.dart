import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:linguaflow/models/quiz_model.dart';

part 'quiz_event.dart';
part 'quiz_state.dart';

class QuizBloc extends Bloc<QuizEvent, QuizState> {
  
  QuizBloc() : super(const QuizState()) {
    on<QuizLoadRequested>(_onLoadRequested);
    on<QuizOptionSelected>(_onOptionSelected);
    on<QuizOptionDeselected>(_onOptionDeselected);
    on<QuizCheckAnswer>(_onCheckAnswer);
    on<QuizNextQuestion>(_onNextQuestion);
  }

  // 1. LOAD QUESTIONS (Using Gemini)
  Future<void> _onLoadRequested(QuizLoadRequested event, Emitter<QuizState> emit) async {
    emit(state.copyWith(status: QuizStatus.loading));

    try {
      // Initialize Gemini
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception("GEMINI_API_KEY missing in .env file");
      }
      Gemini.init(apiKey: apiKey);

      // A. Construct the Prompt for Bidirectional Questions
      final prompt = """
        Generate 10 beginner-level language translation exercises.
        Language A (Target): ${event.targetLanguage}
        Language B (Native): ${event.nativeLanguage}
        
        Return ONLY valid JSON. Do not include markdown formatting like ```json.
        
        Generate a MIX of two types:
        1. "target_to_native": Translate a sentence from ${event.targetLanguage} to ${event.nativeLanguage}.
        2. "native_to_target": Translate a sentence from ${event.nativeLanguage} to ${event.targetLanguage}.
        
        Format:
        [
          {
            "id": "1",
            "type": "target_to_native",
            "targetSentence": "Sentence in Source Language",
            "correctAnswer": "Translation in Result Language",
            "options": ["word1", "word2", "word3"] 
          }
        ]
        
        Rules:
        1. 'options' must contain the words from 'correctAnswer' scattered plus 3-4 distractor words.
        2. Ensure sentences are simple (A1 level).
        3. For "native_to_target", the 'options' must be in ${event.targetLanguage}.
        4. For "target_to_native", the 'options' must be in ${event.nativeLanguage}.
      """;

      // B. Call Gemini
      final value = await Gemini.instance.prompt(parts: [Part.text(prompt)]);
      String? responseText = value?.output;

      if (responseText == null) throw Exception("Empty response from Gemini");

      // C. Clean and Parse JSON
      responseText = responseText.replaceAll('```json', '').replaceAll('```', '').trim();
      
      final List<dynamic> data = jsonDecode(responseText);

      // D. Map to Models
      final questions = data.map((item) {
        return QuizQuestion(
          id: item['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
          type: item['type'] ?? 'target_to_native', // Default
          targetSentence: item['targetSentence'], // The question text
          correctAnswer: item['correctAnswer'], // The result text
          options: List<String>.from(item['options']),
        );
      }).toList();

      if (questions.isEmpty) throw Exception("No questions generated");

      // E. Setup First Question
      final firstQ = questions[0];
      final initialOptions = List<String>.from(firstQ.options)..shuffle();

      emit(state.copyWith(
        status: QuizStatus.answering,
        questions: questions,
        currentIndex: 0,
        selectedWords: [],
        availableWords: initialOptions,
        hearts: 5,
      ));

    } catch (e) {
      print("Quiz Generation Error: $e");
      _loadFallbackData(emit);
    }
  }

  void _loadFallbackData(Emitter<QuizState> emit) {
    final mockQuestions = [
      QuizQuestion(
        id: '1',
        type: 'target_to_native',
        targetSentence: 'Error loading AI. Check connection.',
        correctAnswer: 'Error',
        options: ['Error', 'loading', 'AI', 'Check', 'Key'],
      ),
    ];
    emit(state.copyWith(
      status: QuizStatus.answering,
      questions: mockQuestions,
      availableWords: mockQuestions[0].options,
    ));
  }

  // 2. SELECT WORD
  void _onOptionSelected(QuizOptionSelected event, Emitter<QuizState> emit) {
    if (state.status != QuizStatus.answering) return;

    final newSelected = List<String>.from(state.selectedWords)..add(event.word);
    final newAvailable = List<String>.from(state.availableWords)..remove(event.word);

    emit(state.copyWith(
      selectedWords: newSelected,
      availableWords: newAvailable,
    ));
  }

  // 3. DESELECT WORD
  void _onOptionDeselected(QuizOptionDeselected event, Emitter<QuizState> emit) {
    if (state.status != QuizStatus.answering) return;

    final newSelected = List<String>.from(state.selectedWords)..remove(event.word);
    final newAvailable = List<String>.from(state.availableWords)..add(event.word);

    emit(state.copyWith(
      selectedWords: newSelected,
      availableWords: newAvailable,
    ));
  }

  // 4. CHECK ANSWER
  void _onCheckAnswer(QuizCheckAnswer event, Emitter<QuizState> emit) {
    final currentQ = state.currentQuestion;
    if (currentQ == null) return;

    final userSentence = state.selectedWords.join(" ");
    
    // Normalize
    final cleanUser = userSentence.trim().toLowerCase().replaceAll(RegExp(r'[^\w\s\u00C0-\u017F]'), '');
    final cleanCorrect = currentQ.correctAnswer.trim().toLowerCase().replaceAll(RegExp(r'[^\w\s\u00C0-\u017F]'), '');

    if (cleanUser == cleanCorrect) {
      emit(state.copyWith(status: QuizStatus.correct));
    } else {
      final newHearts = state.hearts - 1;
      emit(state.copyWith(
        status: QuizStatus.incorrect, 
        hearts: newHearts < 0 ? 0 : newHearts
      ));
    }
  }

  // 5. NEXT QUESTION
  void _onNextQuestion(QuizNextQuestion event, Emitter<QuizState> emit) {
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
}