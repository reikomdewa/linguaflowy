import 'package:bloc/bloc.dart';
import 'package:linguaflow/services/repositories/lesson_repository.dart';
// Import the Repository
import 'lesson_event.dart';
import 'lesson_state.dart';

export 'lesson_event.dart';
export 'lesson_state.dart';

class LessonBloc extends Bloc<LessonEvent, LessonState> {
 final LessonRepository _lessonRepository;

  // Constructor using Named Argument ({...})
  LessonBloc({required LessonRepository lessonRepository}) 
      : _lessonRepository = lessonRepository, 
        super(LessonInitial()) {
    
    on<LessonLoadRequested>(_onLessonLoadRequested);
    on<LessonCreateRequested>(_onLessonCreateRequested);
    on<LessonDeleteRequested>(_onLessonDeleteRequested);
    on<LessonUpdateRequested>(_onLessonUpdateRequested);
  }

  Future<void> _onLessonLoadRequested(
    LessonLoadRequested event,
    Emitter<LessonState> emit,
  ) async {
    emit(LessonLoading());
    try {
      // The Repository handles fetching Standard + Native + Firestore and merging them
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
      // Lazy Sync: Saving via repo ensures it's written to Firestore
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
      
      // Optimistic UI Update
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
      // 1. Optimistic Update (Instant Feedback)
      final updatedLessons = currentState.lessons.map((l) {
        return l.id == event.lesson.id ? event.lesson : l;
      }).toList();
      emit(LessonLoaded(updatedLessons));

      try {
        // 2. Lazy Sync: If this was a local lesson, it is now saved to Cloud
        await _lessonRepository.saveOrUpdateLesson(event.lesson);
      } catch (e) {
        print("Update failed: $e");
        emit(currentState); // Revert on failure
      }
    }
  }
}