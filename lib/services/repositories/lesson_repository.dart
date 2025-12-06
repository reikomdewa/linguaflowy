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
    try {
      final results = await Future.wait([
        _firestoreService.getLessons(userId, languageCode),
        _localService.fetchStandardLessons(languageCode),
        _localService.fetchNativeVideos(languageCode),
        _localService.fetchTextBooks(languageCode),
        _localService.fetchBeginnerBooks(languageCode),
            _localService.fetchAudioLessons(languageCode),
      ]);

      final userLessons = results[0];
      final systemStandard = results[1];
      final systemNative = results[2];
      final systemBooks = results[3];
      final beginnerBooks = results[4];
        final systemAudio = results[5];

      final Map<String, LessonModel> combinedMap = {};

      // Local content
      for (var lesson in systemStandard) {
        combinedMap[lesson.id] = lesson;
      }
      for (var lesson in systemNative) {
        combinedMap[lesson.id] = lesson;
      }
      for (var lesson in systemBooks) {
        combinedMap[lesson.id] = lesson;
      }

      // User content
      for (var lesson in userLessons) {
        combinedMap[lesson.id] = lesson;
      }
      for (var lesson in beginnerBooks) {
        combinedMap[lesson.id] = lesson;
      }
 for (var lesson in systemAudio) {
   combinedMap[lesson.id] = lesson;
 }
      final allLessons = combinedMap.values.toList();
      allLessons.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return allLessons;
    } catch (e) {
      return [];
    }
  }

  Future<void> saveOrUpdateLesson(LessonModel lesson) async {
    if (lesson.id.isEmpty) {
      await _firestoreService.createLesson(lesson);
    } else {
      await _firestoreService.updateLesson(lesson);
    }
  }

  Future<void> deleteLesson(String lessonId) async {
    await _firestoreService.deleteLesson(lessonId);
  }
}
