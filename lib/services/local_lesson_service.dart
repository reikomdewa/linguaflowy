import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/transcript_line.dart';

class LocalLessonService {
  
  // 1. Fetch Standard System Lessons (assets/data/lessons_xx.json)
  Future<List<LessonModel>> fetchStandardLessons(String languageCode) async {
    return _loadFromAsset('assets/data/lessons_$languageCode.json', languageCode, 'system');
  }

  // 2. Fetch Native/Trending Videos (assets/native_videos/trending_xx.json)
  Future<List<LessonModel>> fetchNativeVideos(String languageCode) async {
    // We try/catch specifically here because this file might not exist for all languages yet
    try {
      return await _loadFromAsset(
        'assets/native_videos/trending_$languageCode.json', 
        languageCode, 
        'system_native' // distinct ID prefix or user
      );
    } catch (e) {
      print("⚠️ No native videos found for $languageCode (or file missing).");
      return [];
    }
  }

  // --- Helper to reduce code duplication ---
  Future<List<LessonModel>> _loadFromAsset(String path, String languageCode, String defaultUserId) async {
    try {
      final String jsonString = await rootBundle.loadString(path);
      final List<dynamic> data = json.decode(jsonString);
      
      return data.map((jsonItem) {
        // Ensure ID is string
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
          // If coming from native file, Python script sets 'video_native', otherwise 'video'/'text'
          type: jsonItem['type'] ?? 'text', 
          difficulty: jsonItem['difficulty'] ?? 'intermediate',
          videoUrl: jsonItem['videoUrl'],
          isFavorite: jsonItem['isFavorite'] ?? false,
          progress: jsonItem['progress'] ?? 0,
        );
      }).toList();

    } catch (e) {
      // If it's just a missing file (common during dev), return empty
      return [];
    }
  }
}