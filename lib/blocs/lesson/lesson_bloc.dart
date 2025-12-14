import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/services/repositories/lesson_repository.dart';
import 'package:linguaflow/services/gemini_service.dart'; 
import 'lesson_event.dart';
import 'lesson_state.dart';

// Re-exporting for convenience
export 'lesson_event.dart';
export 'lesson_state.dart';

class LessonBloc extends Bloc<LessonEvent, LessonState> {
  final LessonRepository _lessonRepository;
  final GeminiService _geminiService;

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
      emit(LessonError(e.toString()));
    }
  }

  Future<void> _onLessonCreateRequested(
    LessonCreateRequested event,
    Emitter<LessonState> emit,
  ) async {
    final currentState = state;
    try {
      await _lessonRepository.saveOrUpdateLesson(event.lesson);
      // Reload to ensure we have the generated ID and sync state
      add(LessonLoadRequested(event.lesson.userId, event.lesson.language));
    } catch (e) {
      if (currentState is LessonLoaded) {
        emit(LessonLoaded(currentState.lessons)); 
      } else {
        emit(LessonError(e.toString()));
      }
    }
  }

  Future<void> _onLessonUpdateRequested(
    LessonUpdateRequested event,
    Emitter<LessonState> emit,
  ) async {
    final currentState = state;
    if (currentState is LessonLoaded) {
      final originalLessons = currentState.lessons;

      // 1. Optimistic Update (Update UI instantly)
      final updatedLessons = currentState.lessons.map((l) {
        return l.id == event.lesson.id ? event.lesson : l;
      }).toList();
      emit(LessonLoaded(updatedLessons));

      try {
        // 2. Save to DB
        // Use this when marking a lesson as "isCompleted" or "isFavorite"
        await _lessonRepository.saveOrUpdateLesson(event.lesson);
      } catch (e) {
        // 3. Revert on failure
        emit(LessonLoaded(originalLessons));
      }
    }
  }

  Future<void> _onLessonDeleteRequested(
    LessonDeleteRequested event,
    Emitter<LessonState> emit,
  ) async {
    final currentState = state;
    if (currentState is LessonLoaded) {
      final originalLessons = currentState.lessons;

      try {
        final lessonToDelete = currentState.lessons.firstWhere(
          (l) => l.id == event.lessonId,
          orElse: () => throw Exception("Lesson not found in state"),
        );

        // Optimistic Update
        final optimizedList = currentState.lessons
            .where((lesson) => lesson.id != event.lessonId)
            .toList();
        emit(LessonLoaded(optimizedList));

        await _lessonRepository.deleteLesson(lessonToDelete);
      } catch (e) {
        emit(LessonLoaded(originalLessons));
      }
    }
  }

  Future<void> _onLessonGenerateRequested(
    LessonGenerateRequested event,
    Emitter<LessonState> emit,
  ) async {
    emit(LessonLoading());
    try {
      final newLesson = await _geminiService.generateLesson(
        userId: event.userId,
        topic: event.topic,
        level: event.level,
        targetLanguage: event.targetLanguage,
      );

      await _lessonRepository.saveOrUpdateLesson(newLesson);
      emit(LessonGenerationSuccess(newLesson));
    } catch (e) {
      emit(LessonError("Failed to generate AI lesson: $e"));
    }
  }
}