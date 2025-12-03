import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/transcript_line.dart';

class LocalLessonService {
  
  Future<List<LessonModel>> fetchStandardLessons(String languageCode) async {
    print("DEBUG: LocalLessonService -> Fetching Standard Lessons for $languageCode");
    return _loadFromAsset('assets/data/lessons_$languageCode.json', languageCode, 'system');
  }

  Future<List<LessonModel>> fetchNativeVideos(String languageCode) async {
    print("DEBUG: LocalLessonService -> Fetching Native Videos for $languageCode");
    try {
      final results = await _loadFromAsset(
        'assets/native_videos/trending_$languageCode.json', 
        languageCode, 
        'system_native'
      );
      print("DEBUG: LocalLessonService -> Found ${results.length} native videos");
      return results;
    } catch (e) {
      print("DEBUG: LocalLessonService -> ⚠️ Native videos file missing or error: $e");
      // Return empty list so the app doesn't crash
      return [];
    }
  }

  Future<List<LessonModel>> _loadFromAsset(String path, String languageCode, String defaultUserId) async {
    try {
      print("DEBUG: LocalLessonService -> Loading asset: $path");
      final String jsonString = await rootBundle.loadString(path);
      
      final List<dynamic> data = json.decode(jsonString);
      print("DEBUG: LocalLessonService -> JSON decoded, found ${data.length} items");
      
      return data.map((jsonItem) {
        final id = jsonItem['id']?.toString() ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}';
        
        return LessonModel(
          id: id,
          userId: jsonItem['userId'] ?? defaultUserId,
          title: jsonItem['title'] ?? 'Untitled',
          language: jsonItem['language'] ?? languageCode,
          content: jsonItem['content'] ?? '',
          sentences: (jsonItem['sentences'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [],
          transcript: (jsonItem['transcript'] as List<dynamic>?)
              ?.map((e) => TranscriptLine.fromMap(e))
              .toList() ?? [],
          createdAt: DateTime.tryParse(jsonItem['createdAt'] ?? '') ?? DateTime.now(),
          imageUrl: jsonItem['imageUrl'],
          type: jsonItem['type'] ?? 'text', 
          difficulty: jsonItem['difficulty'] ?? 'intermediate',
          videoUrl: jsonItem['videoUrl'],
          isFavorite: jsonItem['isFavorite'] ?? false,
          progress: jsonItem['progress'] ?? 0,
        );
      }).toList();

    } catch (e) {
      print("DEBUG: LocalLessonService -> ❌ Error loading $path: $e");
      // Rethrow native video errors to be caught by the specific method, 
      // but return empty for standard lessons if they fail
      if (path.contains('native')) rethrow;
      return [];
    }
  }
}