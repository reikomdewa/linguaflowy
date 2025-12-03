

// import 'package:bloc/bloc.dart';
// import 'package:linguaflow/models/lesson_model.dart';
// import 'package:linguaflow/services/lesson_service.dart';
// import 'package:linguaflow/services/local_lesson_service.dart';
// import 'package:linguaflow/services/youtube_service.dart';
// // Import the separate event and state files
// import 'lesson_event.dart';
// import 'lesson_state.dart';

// // Export them so other files only need to import lesson_bloc.dart
// export 'lesson_event.dart';
// export 'lesson_state.dart';

// class LessonBloc extends Bloc<LessonEvent, LessonState> {
//   final LessonService lessonService;
//   final LocalLessonService localLessonService;
  

//   LessonBloc(this.lessonService, this.localLessonService) : super(LessonInitial()) {
//     on<LessonLoadRequested>(_onLessonLoadRequested);
//     on<LessonCreateRequested>(_onLessonCreateRequested);
//     on<LessonDeleteRequested>(_onLessonDeleteRequested);
//      on<LessonUpdateRequested>(_onLessonUpdateRequested);
//   }
//  // --- FIXED UPDATE HANDLER ---
//   Future<void> _onLessonUpdateRequested(
//     LessonUpdateRequested event,
//     Emitter<LessonState> emit,
//   ) async {
//     // 1. Keep a reference to the current valid state
//     final currentState = state;
    
//     if (currentState is LessonLoaded) {
//       // 2. OPTIMISTIC UPDATE: Update UI immediately so it feels fast
//       final updatedLessons = currentState.lessons.map((l) {
//         return l.id == event.lesson.id ? event.lesson : l;
//       }).toList();
      
//       // Emit the updated list immediately
//       emit(LessonLoaded(updatedLessons));

//       try {
//         // 3. Attempt database update
//         await lessonService.updateLesson(event.lesson);
//       } catch (e) {
//         print("Update failed: $e");
//         // 4. ERROR HANDLING:
//         // Do NOT emit LessonError, or the screen disappears.
//         // Instead, revert to the original state (undo the star) 
//         // OR just silently reload the data from server.
        
//         // Revert UI to previous state if DB fails
//         emit(currentState); 
//       }
//     }
//   }
// Future<void> _onLessonLoadRequested(
//     LessonLoadRequested event,
//     Emitter<LessonState> emit,
//   ) async {
//     emit(LessonLoading());
    
//     // 1. Local
//     List<LessonModel> localLessons = [];
//     try {
//       localLessons = await lessonService.getLessons(event.userId, event.languageCode);
//       print("BLOC: Loaded ${localLessons.length} local lessons."); // DEBUG
//       emit(LessonLoaded(localLessons)); 
//     } catch (e) {
//       emit(LessonError(e.toString()));
//       return; 
//     }

//     // 2. YouTube
//     try {
//       print("BLOC: Fetching YouTube videos for ${event.languageCode}..."); // DEBUG
//       final userLessons = await lessonService.getLessons(event.userId, event.languageCode);
//       final systemLessons = await localLessonService.fetchLessons(event.languageCode);
//       print("BLOC: Fetched ${systemLessons.length} YouTube videos."); // DEBUG

//       if (systemLessons.isNotEmpty) {
//         final allLessons = [...localLessons, ...systemLessons];
//         // emit(LessonLoaded(allLessons));
//          emit(LessonLoaded([...userLessons, ...systemLessons]));
//       }
//     } catch (e) {
//       print("BLOC ERROR: $e");
//     }
//   }
//   // Future<void> _onLessonLoadRequested(
//   //   LessonLoadRequested event,
//   //   Emitter<LessonState> emit,
//   // ) async {
//   //   emit(LessonLoading());
//   //   try {
//   //     // 1. Local Lessons
//   //     final localLessons = await lessonService.getLessons(event.userId, event.languageCode);
      
//   //     // 2. YouTube Lessons
//   //     final youtubeLessons = await youtubeService.fetchRecommendedVideos(event.languageCode);

//   //     // 3. Merge
//   //     final allLessons = [...localLessons, ...youtubeLessons];
      
//   //     emit(LessonLoaded(allLessons));
//   //   } catch (e) {
//   //     emit(LessonError(e.toString()));
//   //   }
//   // }

//   Future<void> _onLessonCreateRequested(
//     LessonCreateRequested event,
//     Emitter<LessonState> emit,
//   ) async {
//     try {
//       await lessonService.createLesson(event.lesson);
//       // Refresh list with the lesson's language
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



import 'package:bloc/bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/services/lesson_service.dart';
import 'package:linguaflow/services/local_lesson_service.dart';
import 'lesson_event.dart';
import 'lesson_state.dart';

export 'lesson_event.dart';
export 'lesson_state.dart';

class LessonBloc extends Bloc<LessonEvent, LessonState> {
  final LessonService lessonService;
  final LocalLessonService localLessonService;

  LessonBloc(this.lessonService, this.localLessonService) : super(LessonInitial()) {
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
      // 1. Fetch User Data (Firestore) - Contains Favorites & Created Lessons
      final userLessons = await lessonService.getLessons(event.userId, event.languageCode);
      
      // 2. Fetch System Data (YouTube/Local)
      final systemLessons = await localLessonService.fetchLessons(event.languageCode);

      // 3. MERGE LOGIC (The Fix):
      // We want all User lessons.
      // We ONLY want System lessons if they are NOT already in the User list.
      // This prevents duplicates and ensures the 'Favorite' status from Firestore is kept.
      
      // Create a Set of IDs that exist in Firestore for fast lookup
      final userLessonIds = userLessons.map((l) => l.id).toSet();

      // Filter system lessons: Only keep ones that are NOT in Firestore
      final newSystemLessons = systemLessons.where((sysLesson) {
        return !userLessonIds.contains(sysLesson.id);
      }).toList();

      // Combine them
      final allLessons = [...userLessons, ...newSystemLessons];

      // Sort by date (optional, keeps new stuff at top)
      allLessons.sort((a, b) => b.createdAt.compareTo(a.createdAt));

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
      await lessonService.createLesson(event.lesson);
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
        await lessonService.updateLesson(event.lesson);
      } catch (e) {
        print("Update failed: $e");
        // Revert on failure
        emit(currentState);
      }
    }
  }
}