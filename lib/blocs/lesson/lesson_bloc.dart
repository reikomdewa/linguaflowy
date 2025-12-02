// import 'package:bloc/bloc.dart';
// import 'package:linguaflow/models/lesson_model.dart';
// import 'package:linguaflow/services/lesson_service.dart';

// // Events
// abstract class LessonEvent {}

// class LessonLoadRequested extends LessonEvent {
//   final String userId;
//   final String languageCode; // Add this
//   LessonLoadRequested(this.userId, this.languageCode);
// }

// class LessonCreateRequested extends LessonEvent {
//   final LessonModel lesson;
//   LessonCreateRequested(this.lesson);
// }

// class LessonDeleteRequested extends LessonEvent {
//   final String lessonId;
//   LessonDeleteRequested(this.lessonId);
// }

// // States
// abstract class LessonState {}
// class LessonInitial extends LessonState {}
// class LessonLoading extends LessonState {}
// class LessonLoaded extends LessonState {
//   final List<LessonModel> lessons;
//   LessonLoaded(this.lessons);
// }
// class LessonError extends LessonState {
//   final String message;
//   LessonError(this.message);
// }

// // Bloc
// class LessonBloc extends Bloc<LessonEvent, LessonState> {
//   final LessonService lessonService;

//   LessonBloc(this.lessonService) : super(LessonInitial()) {
//     on<LessonLoadRequested>(_onLessonLoadRequested);
//     on<LessonCreateRequested>(_onLessonCreateRequested);
//     on<LessonDeleteRequested>(_onLessonDeleteRequested);
//   }

//   Future<void> _onLessonLoadRequested(
//     LessonLoadRequested event,
//     Emitter<LessonState> emit,
//   ) async {
//     emit(LessonLoading());
//     try {
//       // Pass the language code to the service
//       final lessons = await lessonService.getLessons(event.userId, event.languageCode);
//       emit(LessonLoaded(lessons));
//     } catch (e) {
//       emit(LessonError(e.toString()));
//     }
//   }

//   Future<void> _onLessonCreateRequested(
//     LessonCreateRequested event,
//     Emitter<LessonState> emit,
//   ) async {
//     try {
//       await lessonService.createLesson(event.lesson);
//       // Reload using the lesson's language
//       add(LessonLoadRequested(event.lesson.userId, event.lesson.language)); 
//     } catch (e) {
//       emit(LessonError(e.toString()));
//     }
//   }

//   Future<void> _onLessonDeleteRequested(
//     LessonDeleteRequested event,
//     Emitter<LessonState> emit,
//   ) async {
//     try {
//       await lessonService.deleteLesson(event.lessonId);
//       // Optimistic update
//       if (state is LessonLoaded) {
//         final currentLessons = (state as LessonLoaded).lessons;
//         final updatedLessons = currentLessons
//             .where((lesson) => lesson.id != event.lessonId)
//             .toList();
//         emit(LessonLoaded(updatedLessons));
//       }
//     } catch (e) {
//       emit(LessonError(e.toString()));
//     }
//   }
// }

// File: lib/blocs/lesson/lesson_bloc.dart

import 'package:bloc/bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/services/lesson_service.dart';
import 'package:linguaflow/services/youtube_service.dart';
// Import the separate event and state files
import 'lesson_event.dart';
import 'lesson_state.dart';

// Export them so other files only need to import lesson_bloc.dart
export 'lesson_event.dart';
export 'lesson_state.dart';

class LessonBloc extends Bloc<LessonEvent, LessonState> {
  final LessonService lessonService;
  final YouTubeService youtubeService;

  LessonBloc(this.lessonService, this.youtubeService) : super(LessonInitial()) {
    on<LessonLoadRequested>(_onLessonLoadRequested);
    on<LessonCreateRequested>(_onLessonCreateRequested);
    on<LessonDeleteRequested>(_onLessonDeleteRequested);
  }
Future<void> _onLessonLoadRequested(
    LessonLoadRequested event,
    Emitter<LessonState> emit,
  ) async {
    emit(LessonLoading());
    
    // 1. Local
    List<LessonModel> localLessons = [];
    try {
      localLessons = await lessonService.getLessons(event.userId, event.languageCode);
      print("BLOC: Loaded ${localLessons.length} local lessons."); // DEBUG
      emit(LessonLoaded(localLessons)); 
    } catch (e) {
      emit(LessonError(e.toString()));
      return; 
    }

    // 2. YouTube
    try {
      print("BLOC: Fetching YouTube videos for ${event.languageCode}..."); // DEBUG
      final youtubeLessons = await youtubeService.fetchRecommendedVideos(event.languageCode);
      print("BLOC: Fetched ${youtubeLessons.length} YouTube videos."); // DEBUG

      if (youtubeLessons.isNotEmpty) {
        final allLessons = [...localLessons, ...youtubeLessons];
        emit(LessonLoaded(allLessons));
      }
    } catch (e) {
      print("BLOC ERROR: $e");
    }
  }
  // Future<void> _onLessonLoadRequested(
  //   LessonLoadRequested event,
  //   Emitter<LessonState> emit,
  // ) async {
  //   emit(LessonLoading());
  //   try {
  //     // 1. Local Lessons
  //     final localLessons = await lessonService.getLessons(event.userId, event.languageCode);
      
  //     // 2. YouTube Lessons
  //     final youtubeLessons = await youtubeService.fetchRecommendedVideos(event.languageCode);

  //     // 3. Merge
  //     final allLessons = [...localLessons, ...youtubeLessons];
      
  //     emit(LessonLoaded(allLessons));
  //   } catch (e) {
  //     emit(LessonError(e.toString()));
  //   }
  // }

  Future<void> _onLessonCreateRequested(
    LessonCreateRequested event,
    Emitter<LessonState> emit,
  ) async {
    try {
      await lessonService.createLesson(event.lesson);
      // Refresh list with the lesson's language
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