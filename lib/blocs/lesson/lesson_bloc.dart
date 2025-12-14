import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/services/repositories/lesson_repository.dart';
import 'package:linguaflow/services/gemini_service.dart'; 
import 'package:linguaflow/models/lesson_model.dart';
import 'lesson_event.dart';
import 'lesson_state.dart';

// Re-exporting for convenience
export 'lesson_event.dart';
export 'lesson_state.dart';

class LessonBloc extends Bloc<LessonEvent, LessonState> {
  final LessonRepository _lessonRepository;
  final GeminiService _geminiService;

  // --- STATE VARIABLES FOR PAGINATION ---
  String? _currentUserId;
  String? _currentLanguageCode;

  LessonBloc({
    required LessonRepository lessonRepository,
    required GeminiService geminiService, 
  })  : _lessonRepository = lessonRepository,
        _geminiService = geminiService,
        super(LessonInitial()) {
    
    on<LessonLoadRequested>(_onLessonLoadRequested);
    on<LoadMoreLessons>(_onLoadMoreLessons); // <--- NEW HANDLER
    on<LessonCreateRequested>(_onLessonCreateRequested);
    on<LessonDeleteRequested>(_onLessonDeleteRequested);
    on<LessonUpdateRequested>(_onLessonUpdateRequested);
    on<LessonGenerateRequested>(_onLessonGenerateRequested);
  }

  // 1. INITIAL LOAD (Resets everything)
  Future<void> _onLessonLoadRequested(
    LessonLoadRequested event,
    Emitter<LessonState> emit,
  ) async {
    emit(LessonLoading());
    
    // Save these for later use in pagination
    _currentUserId = event.userId;
    _currentLanguageCode = event.languageCode;

    try {
      // Fetch only the first 20 (defined by Repository default)
      final allLessons = await _lessonRepository.getAndSyncLessons(
        event.userId, 
        event.languageCode
      );
      
      emit(LessonLoaded(
        allLessons,
        hasReachedMax: false, // We assume there might be more
      ));
    } catch (e) {
      emit(LessonError(e.toString()));
    }
  }

  // 2. LOAD MORE (Triggered by Scroll)
  Future<void> _onLoadMoreLessons(
    LoadMoreLessons event,
    Emitter<LessonState> emit,
  ) async {
    final currentState = state;
    
    // Guard clauses to prevent spamming the API
    if (currentState is! LessonLoaded) return;
    if (currentState.hasReachedMax) return; 
    if (currentState.isLoadingMore) return;
    if (_currentUserId == null || _currentLanguageCode == null) return;

    // Show loading spinner at bottom
    emit(currentState.copyWith(isLoadingMore: true));

    try {
      final lastLesson = currentState.lessons.last;

      // Ask Repository for next batch
      final newLessons = await _lessonRepository.fetchMoreUserLessons(
        _currentUserId!,
        _currentLanguageCode!,
        lastLesson, 
      );

      // Append new lessons to the existing list
      emit(currentState.copyWith(
        lessons: List.of(currentState.lessons)..addAll(newLessons),
        hasReachedMax: newLessons.isEmpty, // If we got 0, we are done.
        isLoadingMore: false,
      ));
    } catch (e) {
      // If pagination fails, just stop the spinner. Don't crash the UI.
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  // --- EXISTING CRUD OPERATIONS (Unchanged) ---

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
        emit(currentState); // Keep showing list
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

      // Optimistic Update
      final updatedLessons = currentState.lessons.map((l) {
        return l.id == event.lesson.id ? event.lesson : l;
      }).toList();
      
      emit(currentState.copyWith(lessons: updatedLessons));

      try {
        await _lessonRepository.saveOrUpdateLesson(event.lesson);
      } catch (e) {
        // Revert on failure
        emit(currentState.copyWith(lessons: originalLessons));
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
          orElse: () => throw Exception("Lesson not found"),
        );

        final optimizedList = currentState.lessons
            .where((lesson) => lesson.id != event.lessonId)
            .toList();
            
        emit(currentState.copyWith(lessons: optimizedList));

        await _lessonRepository.deleteLesson(lessonToDelete);
      } catch (e) {
        emit(currentState.copyWith(lessons: originalLessons));
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