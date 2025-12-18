import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:linguaflow/models/lesson_model.dart';

class LessonCacheService {
  static const String _prefix = 'lesson_cache_';
  // Inside HomeFeedCacheService (or LessonCacheService)


  // Singleton instance
  static final LessonCacheService _instance = LessonCacheService._internal();
  factory LessonCacheService() => _instance;
  LessonCacheService._internal();

  /// Save a single lesson to local storage
  Future<void> cacheLesson(LessonModel lesson) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String key = '$_prefix${lesson.id}';
      
      // Convert model to Map, then to JSON string
      String jsonString = jsonEncode(lesson.toMap());
      
      await prefs.setString(key, jsonString);
      // debugPrint("📦 Cached lesson locally: ${lesson.title}");
    } catch (e) {
      // debugPrint("⚠️ Failed to cache lesson: $e");
    }
  }

  /// Try to get a lesson from local storage
  Future<LessonModel?> getLesson(String lessonId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String key = '$_prefix$lessonId';
      
      final String? jsonString = prefs.getString(key);
      if (jsonString == null) return null;

      final Map<String, dynamic> map = jsonDecode(jsonString);
      return LessonModel.fromMap(map, lessonId);
    } catch (e) {
      return null;
    }
  }

  /// Clear specific cache (useful if user updates/deletes a lesson)
  Future<void> removeLesson(String lessonId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$lessonId');
  }
}