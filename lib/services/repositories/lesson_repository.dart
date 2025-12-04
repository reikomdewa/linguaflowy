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

  Future<List<LessonModel>> getAndSyncLessons(String userId, String languageCode) async {
    print("DEBUG: Repository -> getAndSyncLessons STARTED");
    try {
      // 1. Fetch all 3 sources
      final results = await Future.wait([
        _firestoreService.getLessons(userId, languageCode),
        _localService.fetchStandardLessons(languageCode),
        _localService.fetchNativeVideos(languageCode),
      ]);

      final userLessons = results[0];
      final systemStandard = results[1];
      final systemNative = results[2];

      print("DEBUG: Repository -> Retrieved: Cloud(${userLessons.length}), Standard(${systemStandard.length}), Native(${systemNative.length})");

      // 2. Merge Logic
      final Map<String, LessonModel> combinedMap = {};

      for (var lesson in systemStandard) {
        combinedMap[lesson.id] = lesson;
      }
      for (var lesson in systemNative) {
        combinedMap[lesson.id] = lesson;
      }
      for (var lesson in userLessons) {
        combinedMap[lesson.id] = lesson;
      }

      final allLessons = combinedMap.values.toList();
      allLessons.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      print("DEBUG: Repository -> Final merged count: ${allLessons.length}");
      return allLessons;
    } catch (e) {
      print("DEBUG: Repository -> ❌ CRITICAL ERROR in getAndSyncLessons: $e");
      return [];
    }
  }

  Future<void> saveOrUpdateLesson(LessonModel lesson) async {
    print("DEBUG: Repository -> saveOrUpdateLesson called. ID is: '${lesson.id}'");
    
    // THE FIX LOGIC
    if (lesson.id.isEmpty) {
      print("DEBUG: Repository -> ID is empty. Routing to CREATE.");
      await _firestoreService.createLesson(lesson);
    } else {
      print("DEBUG: Repository -> ID exists. Routing to UPDATE.");
      await _firestoreService.updateLesson(lesson);
    }
  }

  Future<void> deleteLesson(String lessonId) async {
    print("DEBUG: Repository -> deleteLesson called for $lessonId");
    await _firestoreService.deleteLesson(lessonId);
  }
}