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
    try {
      // Repository handles logic for Local vs Firestore based on lesson.isLocal
      await _lessonRepository.saveOrUpdateLesson(event.lesson);
      
      // Reload the list to show the new item
      add(LessonLoadRequested(event.lesson.userId, event.lesson.language));
    } catch (e) {
      emit(LessonError(e.toString()));
    }
  }

  Future<void> _onLessonDeleteRequested(
    LessonDeleteRequested event,
    Emitter<LessonState> emit,
  ) async {
    final currentState = state;
    
    // We need the full LessonModel to know if we are deleting a Local file or a Firestore doc
    if (currentState is LessonLoaded) {
      try {
        // 1. Find the lesson object in current state
        final lessonToDelete = currentState.lessons.firstWhere(
          (l) => l.id == event.lessonId,
          orElse: () => throw Exception("Lesson not found in state"),
        );

        // 2. Pass the full object to repository so it knows WHERE to delete from
        await _lessonRepository.deleteLesson(lessonToDelete);
        
        // 3. Optimistically update UI
        final updatedLessons = currentState.lessons
            .where((lesson) => lesson.id != event.lessonId)
            .toList();
        
        emit(LessonLoaded(updatedLessons));
      } catch (e) {
        emit(LessonError("Failed to delete lesson: $e"));
        // Optionally trigger a reload to ensure sync
        // if (currentState.lessons.isNotEmpty) {
        //   add(LessonLoadRequested(currentState.lessons.first.userId, currentState.lessons.first.language));
        // }
      }
    }
  }

  Future<void> _onLessonUpdateRequested(
    LessonUpdateRequested event,
    Emitter<LessonState> emit,
  ) async {
    final currentState = state;
    if (currentState is LessonLoaded) {
      // Optimistic Update
      final updatedLessons = currentState.lessons.map((l) {
        return l.id == event.lesson.id ? event.lesson : l;
      }).toList();
      emit(LessonLoaded(updatedLessons));

      try {
        await _lessonRepository.saveOrUpdateLesson(event.lesson);
      } catch (e) {
        // If update fails, revert to previous state or show error
        // For now, we just emit the error but keep the list (or reload)
        emit(LessonError("Failed to update lesson: $e"));
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

      // 2. Save to Database (AI lessons are usually cloud-synced, so isLocal defaults to false)
      await _lessonRepository.saveOrUpdateLesson(newLesson);

      // 3. Emit SUCCESS
      emit(LessonGenerationSuccess(newLesson));

    } catch (e) {
      emit(LessonError("Failed to generate AI lesson: $e"));
    }
  }
}