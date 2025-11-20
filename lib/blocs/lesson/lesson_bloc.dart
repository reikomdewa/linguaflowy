// LESSON BLOC
// ==========================================
// File: lib/blocs/lesson/lesson_bloc.dart
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/user_model.dart';
import 'package:linguaflow/services/lesson_service.dart';
  

// Events
abstract class LessonEvent {}

class LessonLoadRequested extends LessonEvent {
  final String userId;
  LessonLoadRequested(this.userId);
}

class LessonCreateRequested extends LessonEvent {
  final LessonModel lesson;
  LessonCreateRequested(this.lesson);
}

class LessonDeleteRequested extends LessonEvent {
  final String lessonId;
  LessonDeleteRequested(this.lessonId);
}

// States
abstract class LessonState {}

class LessonInitial extends LessonState {}

class LessonLoading extends LessonState {}

class LessonLoaded extends LessonState {
  final List<LessonModel> lessons;
  LessonLoaded(this.lessons);
}

class LessonError extends LessonState {
  final String message;
  LessonError(this.message);
}

// Bloc
class LessonBloc extends Bloc<LessonEvent, LessonState> {
  final LessonService lessonService;

  LessonBloc(this.lessonService) : super(LessonInitial()) {
    on<LessonLoadRequested>(_onLessonLoadRequested);
    on<LessonCreateRequested>(_onLessonCreateRequested);
    on<LessonDeleteRequested>(_onLessonDeleteRequested);
  }

  Future<void> _onLessonLoadRequested(
    LessonLoadRequested event,
    Emitter<LessonState> emit,
  ) async {
    emit(LessonLoading());
    try {
      final lessons = await lessonService.getLessons(event.userId);
      emit(LessonLoaded(lessons));
    } catch (e) {
      emit(LessonError(e.toString()));
    }
  }

  Future<void> _onLessonCreateRequested(
    LessonCreateRequested event,
    Emitter<LessonState> emit,
  ) async {
    try {
      await lessonService.createLesson(event.lesson);
      add(LessonLoadRequested(event.lesson.userId));
    } catch (e) {
      emit(LessonError(e.toString()));
    }
  }

  Future<void> _onLessonDeleteRequested(
    LessonDeleteRequested event,
    Emitter<LessonState> emit,
  ) async {
    try {
      await lessonService.deleteLesson(event.lessonId);
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
}