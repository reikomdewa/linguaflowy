


import 'package:bloc/bloc.dart';
import 'package:linguaflow/services/repositories/lesson_repository.dart';
import 'package:linguaflow/services/gemini_service.dart'; // Import Service

import 'lesson_event.dart';
import 'lesson_state.dart';

export 'lesson_event.dart';
export 'lesson_state.dart';

class LessonBloc extends Bloc<LessonEvent, LessonState> {
  final LessonRepository _lessonRepository;
  final GeminiService _geminiService; // 1. Add Service Variable

  // 2. Update Constructor to require GeminiService
  LessonBloc({
    required LessonRepository lessonRepository,
    required GeminiService geminiService, 
  })  : _lessonRepository = lessonRepository,
        _geminiService = geminiService,
        super(LessonInitial()) {
    
    on<LessonLoadRequested>(_onLessonLoadRequested);
    on<LessonCreateRequested>(_onLessonCreateRequested);
    on<LessonDeleteRequested>(_onLessonDeleteRequested);
    on<LessonUpdateRequested>(_onLessonUpdateRequested);
    
    // 3. Register New Handler
    on<LessonGenerateRequested>(_onLessonGenerateRequested);
  }

  Future<void> _onLessonLoadRequested(
    LessonLoadRequested event,
    Emitter<LessonState> emit,
  ) async {
    emit(LessonLoading());
    try {
      final allLessons = await _lessonRepository.getAndSyncLessons(
        event.userId, 
        event.languageCode
      );
      emit(LessonLoaded(allLessons));
    } catch (e) {
      print("BLOC LOAD ERROR: $e");
      emit(LessonError(e.toString()));
    }
  }

  Future<void> _onLessonCreateRequested(
    LessonCreateRequested event,
    Emitter<LessonState> emit,
  ) async {
    try {
      await _lessonRepository.saveOrUpdateLesson(event.lesson);
      add(LessonLoadRequested(event.lesson.userId, event.lesson.language));
    } catch (e) {
      emit(LessonError(e.toString()));
    }
  }

  Future<void> _onLessonDeleteRequested(
    LessonDeleteRequested event,
    Emitter<LessonState> emit,
  ) async {
    try {
      await _lessonRepository.deleteLesson(event.lessonId);
      
      if (state is LessonLoaded) {
        final currentLessons = (state as LessonLoaded).lessons;
        final updatedLessons = currentLessons
            .where((lesson) => lesson.id != event.lessonId)
            .toList();
        emit(LessonLoaded(updatedLessons));
      }
    } catch (e) {
      emit(LessonError(e.toString()));
    }
  }

  Future<void> _onLessonUpdateRequested(
    LessonUpdateRequested event,
    Emitter<LessonState> emit,
  ) async {
    final currentState = state;
    if (currentState is LessonLoaded) {
      final updatedLessons = currentState.lessons.map((l) {
        return l.id == event.lesson.id ? event.lesson : l;
      }).toList();
      emit(LessonLoaded(updatedLessons));

      try {
        await _lessonRepository.saveOrUpdateLesson(event.lesson);
      } catch (e) {
        print("Update failed: $e");
        emit(currentState); 
      }
    }
  }
Future<void> _onLessonGenerateRequested(
    LessonGenerateRequested event,
    Emitter<LessonState> emit,
  ) async {
    emit(LessonLoading());

    try {
      // 1. Generate via Gemini
      final newLesson = await _geminiService.generateLesson(
        userId: event.userId,
        topic: event.topic,
        level: event.level,
        targetLanguage: event.targetLanguage,
      );

      // 2. Save to Database
      await _lessonRepository.saveOrUpdateLesson(newLesson);

      // 3. EMIT SUCCESS
      // This tells the UI to show the Story Mode.
      emit(LessonGenerationSuccess(newLesson));

      // --- DELETE OR COMMENT OUT THIS LINE ---
      // add(LessonLoadRequested(event.userId, event.targetLanguage)); 
      // ---------------------------------------
      // Why? Because this triggers "LessonLoading" again immediately, 
      // causing the "Making your story..." screen to spin forever.
      // The list will refresh naturally next time the user visits the library.

    } catch (e) {
      emit(LessonError("Failed to generate AI lesson: $e"));
    }
  }

}