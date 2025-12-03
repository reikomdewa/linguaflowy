import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/services/lesson_service.dart';
import 'package:linguaflow/services/local_lesson_service.dart';

class LessonRepository {
  final LessonService _firestoreService;
  final LocalLessonService _localService;

  LessonRepository({
    required LessonService firestoreService,
    required LocalLessonService localService,
  })  : _firestoreService = firestoreService,
        _localService = localService;

  // --- READ-MERGE LOGIC ---
  Future<List<LessonModel>> getAndSyncLessons(String userId, String languageCode) async {
    try {
      // 1. Fetch all 3 sources in parallel
      final results = await Future.wait([
        _firestoreService.getLessons(userId, languageCode),
        _localService.fetchStandardLessons(languageCode), // Correct Method Name
        _localService.fetchNativeVideos(languageCode),    // Correct Method Name
      ]);

      final userLessons = results[0];
      final systemStandard = results[1];
      final systemNative = results[2];

      // 2. Merge Logic: Firestore overrides Local
      final Map<String, LessonModel> combinedMap = {};

      // Add Local content first
      for (var lesson in systemStandard) combinedMap[lesson.id] = lesson;
      for (var lesson in systemNative) combinedMap[lesson.id] = lesson;

      // Add Firestore content (Overrides local if ID exists)
      for (var lesson in userLessons) combinedMap[lesson.id] = lesson;

      // 3. Sort by Newest
      final allLessons = combinedMap.values.toList();
      allLessons.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return allLessons;
    } catch (e) {
      print("Repository Error: $e");
      return [];
    }
  }

  // --- WRITE-COPY LOGIC ---
  Future<void> saveOrUpdateLesson(LessonModel lesson) async {
    // This turns a local lesson into a cloud lesson if it wasn't one already
    await _firestoreService.updateLesson(lesson);
  }

  Future<void> deleteLesson(String lessonId) async {
    await _firestoreService.deleteLesson(lessonId);
  }
}