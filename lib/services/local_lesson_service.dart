import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/transcript_line.dart';

class LocalLessonService {
  
  Future<List<LessonModel>> fetchStandardLessons(String languageCode) async {
    return _loadFromAsset('assets/data/lessons_$languageCode.json', languageCode, 'system');
  }

  Future<List<LessonModel>> fetchNativeVideos(String languageCode) async {
    try {
      return await _loadFromAsset(
        'assets/native_videos/trending_$languageCode.json',
        languageCode,
        'system_native',
      );
    } catch (e) {
      return [];
    }
  }

  Future<List<LessonModel>> _loadFromAsset(
    String path,
    String languageCode,
    String defaultUserId,
  ) async {
    try {
      final String jsonString = await rootBundle.loadString(path);
      final List<dynamic> data = json.decode(jsonString);

      return data.map((jsonItem) {
        final id = jsonItem['id']?.toString() ??
            'unknown_${DateTime.now().millisecondsSinceEpoch}';

        return LessonModel(
          id: id,
          userId: jsonItem['userId'] ?? defaultUserId,
          title: jsonItem['title'] ?? 'Untitled',
          language: jsonItem['language'] ?? languageCode,
          content: jsonItem['content'] ?? '',
          sentences: (jsonItem['sentences'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
          transcript: (jsonItem['transcript'] as List<dynamic>?)
                  ?.map((e) => TranscriptLine.fromMap(e))
                  .toList() ??
              [],
          createdAt: DateTime.tryParse(jsonItem['createdAt'] ?? '') ??
              DateTime.now(),
          imageUrl: jsonItem['imageUrl'],
          type: jsonItem['type'] ?? 'text',
          difficulty: jsonItem['difficulty'] ?? 'intermediate',
          videoUrl: jsonItem['videoUrl'],
          isFavorite: jsonItem['isFavorite'] ?? false,
          progress: jsonItem['progress'] ?? 0,
        );
      }).toList();
    } catch (e) {
      if (path.contains('native')) rethrow;
      return [];
    }
  }

  Future<List<LessonModel>> fetchTextBooks(String languageCode) async {
    try {
      return await _loadFromAsset(
        'assets/text_lessons/books_$languageCode.json',
        languageCode,
        'system_gutenberg',
      );
    } catch (e) {
      return [];
    }
  }

  Future<List<LessonModel>> fetchBeginnerBooks(String languageCode) async {
    try {
      return await _loadFromAsset(
        'assets/beginner_books/beginner_$languageCode.json',
        languageCode,
        'system_beginner',
      );
    } catch (e) {
      return [];
    }
  }
}
