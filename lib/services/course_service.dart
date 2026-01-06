import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/utils/logger.dart';

class CourseService {
  Future<List<LessonModel>> getCourseLessons({
    required String languageCode,
    required String userLevel,
    required String categoryFilter,
  }) async {
    try {
      final String path = 'assets/course_videos/$languageCode.json';
      // print("DEBUG: Loading course file: $path");

      final String jsonString = await rootBundle.loadString(path);
      final List<dynamic> jsonList = jsonDecode(jsonString);

      final allLessons = jsonList
          .map((j) => LessonModel.fromMap(j, j['id']))
          .toList();

      // 1. DETERMINE TARGET TYPE
      String targetType = '';
      if (categoryFilter == 'Stories') targetType = 'story';
      if (categoryFilter == 'News') targetType = 'news';
      if (categoryFilter == 'Bites') targetType = 'bite';
      if (categoryFilter == 'Grammar tips') targetType = 'grammar';
      // If 'All', targetType remains empty

      // 2. DETERMINE DIFFICULTY
      String userDifficulty = 'beginner';
      if (userLevel.toLowerCase().contains('intermediate')) {
        userDifficulty = 'intermediate';
      }
      if (userLevel.toLowerCase().contains('advanced')) {
        userDifficulty = 'advanced';
      }

      // 3. FILTERING
      var filtered = allLessons.where((l) {
        // Filter by Type (unless 'All')
        if (categoryFilter != 'All' && l.type != targetType) return false;

        // Difficulty Logic
        if (userDifficulty == 'advanced') return true;
        if (userDifficulty == 'intermediate') return l.difficulty != 'advanced';
        return l.difficulty == 'beginner' || l.difficulty == 'intermediate';
      }).toList();

      // Fallback
      if (filtered.isEmpty) return allLessons;

      return filtered;
    } catch (e) {
      print("ERROR: Could not load course videos. Details: $e");
      return [];
    }
  }
}
