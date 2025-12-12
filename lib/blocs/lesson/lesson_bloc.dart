import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/services/repositories/lesson_repository.dart';
import 'package:linguaflow/services/gemini_service.dart'; 
import 'lesson_event.dart';
import 'lesson_state.dart';

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
    // DEBUG PRINT
    print("🔵 [Bloc] Creating Lesson. ID should be empty: '${event.lesson.id}'");
    print("🔵 [Bloc] Target: isLocal=${event.lesson.isLocal}, userId=${event.lesson.userId}");

    final currentState = state;
    try {
      await _lessonRepository.saveOrUpdateLesson(event.lesson);
      // Reload the list to show the new item
      add(LessonLoadRequested(event.lesson.userId, event.lesson.language));
    } catch (e) {
      print("🔴 [Bloc] Create Failed: $e");
      if (currentState is LessonLoaded) {
        // Prevent list from disappearing on error
        emit(LessonLoaded(currentState.lessons)); 
      } else {
        emit(LessonError(e.toString()));
      }
    }
  }

  Future<void> _onLessonDeleteRequested(
    LessonDeleteRequested event,
    Emitter<LessonState> emit,
  ) async {
    final currentState = state;
    
    if (currentState is LessonLoaded) {
      // 1. Keep a copy of original
      final originalLessons = currentState.lessons;

      try {
        final lessonToDelete = currentState.lessons.firstWhere(
          (l) => l.id == event.lessonId,
          orElse: () => throw Exception("Lesson not found in state"),
        );

        // 2. Optimistic Update (Remove visually)
        final optimizedList = currentState.lessons
            .where((lesson) => lesson.id != event.lessonId)
            .toList();
        
        emit(LessonLoaded(optimizedList));

        // 3. Delete from DB
        await _lessonRepository.deleteLesson(lessonToDelete);
        
      } catch (e) {
        print("🔴 [Bloc] Delete Failed. Reverting UI: $e");
        // 4. Revert on failure
        emit(LessonLoaded(originalLessons));
      }
    }
  }

  Future<void> _onLessonUpdateRequested(
    LessonUpdateRequested event,
    Emitter<LessonState> emit,
  ) async {
    final currentState = state;
    if (currentState is LessonLoaded) {
      // 1. Keep copy
      final originalLessons = currentState.lessons;

      // 2. Optimistic Update
      final updatedLessons = currentState.lessons.map((l) {
        return l.id == event.lesson.id ? event.lesson : l;
      }).toList();
      emit(LessonLoaded(updatedLessons));

      try {
        // 3. Save to DB
        await _lessonRepository.saveOrUpdateLesson(event.lesson);
      } catch (e) {
        print("🔴 [Bloc] Update Failed. Reverting UI: $e");
        // 4. Revert on failure
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