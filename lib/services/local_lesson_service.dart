import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/transcript_line.dart';

class LocalLessonService {
  /// Fetches standard text/video lessons
  Future<List<LessonModel>> fetchStandardLessons(String languageCode) async {
    return _loadFromAsset(
      'assets/data/lessons_$languageCode.json',
      languageCode,
      'system',
    );
  }

  /// Fetches native trending videos
  Future<List<LessonModel>> fetchNativeVideos(String languageCode) async {
    return _loadFromAsset(
      'assets/native_videos/trending_$languageCode.json',
      languageCode,
      'system_native',
    );
  }

  /// Fetches Audio content (Combines LibriVox + YouTube Audiobooks)
  Future<List<LessonModel>> fetchAudioLessons(String languageCode) async {
    List<LessonModel> allAudio = [];

    // 1. Fetch LibriVox Audio (Pure Audio)
    // These files are expected in: assets/audio_library/
    try {
      final librivox = await _loadFromAsset(
        'assets/audio_library/audio_$languageCode.json',
        languageCode,
        'system_librivox',
      );
      if (librivox.isNotEmpty) {
        allAudio.addAll(librivox);
      }
    } catch (e) {
      // We catch here specifically to allow the next part (Audiobooks) to still try loading
      print("⚠️ LibriVox Load Skipped: $e");
    }

    // 2. Fetch Synced Audiobooks (YouTube Audio)
    // These files are expected in: assets/youtube_audio_library/
    try {
      final audiobooks = await _loadFromAsset(
        'assets/youtube_audio_library/audiobooks_$languageCode.json',
        languageCode,
        'system_audiobook',
      );
      if (audiobooks.isNotEmpty) {
        allAudio.addAll(audiobooks);
      }
    } catch (e) {
      print("⚠️ Audiobooks Load Skipped: $e");
    }

    return allAudio;
  }

  /// Fetches Gutenberg Books
  Future<List<LessonModel>> fetchTextBooks(String languageCode) async {
    return _loadFromAsset(
      'assets/text_lessons/books_$languageCode.json',
      languageCode,
      'system_gutenberg',
    );
  }

  /// Fetches Beginner Books
  Future<List<LessonModel>> fetchBeginnerBooks(String languageCode) async {
    return _loadFromAsset(
      'assets/beginner_books/beginner_$languageCode.json',
      languageCode,
      'system_beginner',
    );
  }

  // --- CORE LOADING LOGIC ---
  Future<List<LessonModel>> _loadFromAsset(
    String path,
    String languageCode,
    String defaultUserId,
  ) async {
    try {
      // 1. Attempt to load string from assets
      final String jsonString = await rootBundle.loadString(path);

      // 2. Decode JSON
      final List<dynamic> data = json.decode(jsonString);

      // 3. Map to LessonModel
      return data.map((jsonItem) {
        final id =
            jsonItem['id']?.toString() ??
            'unknown_${DateTime.now().millisecondsSinceEpoch}';

        // --- URL MAPPING FIX ---
        // Some JSON files (LibriVox) use 'audioUrl', others use 'videoUrl'.
        // We normalize this into the 'videoUrl' field of LessonModel.
        String? mediaUrl = jsonItem['videoUrl']?.toString();
        if (mediaUrl == null || mediaUrl.isEmpty) {
          mediaUrl = jsonItem['audioUrl']?.toString();
        }

        return LessonModel(
          id: id,
          userId: jsonItem['userId'] ?? defaultUserId,
          title: jsonItem['title'] ?? 'Untitled',
          language: jsonItem['language'] ?? languageCode,
          content: jsonItem['content'] ?? '',
          // Safely convert list of strings
          sentences:
              (jsonItem['sentences'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
          // Safely convert transcripts
          transcript:
              (jsonItem['transcript'] as List<dynamic>?)
                  ?.map((e) => TranscriptLine.fromMap(e))
                  .toList() ??
              [],
          createdAt:
              DateTime.tryParse(jsonItem['createdAt'] ?? '') ?? DateTime.now(),
          imageUrl: jsonItem['imageUrl'],
          type: jsonItem['type'] ?? 'text',
          difficulty: jsonItem['difficulty'] ?? 'intermediate',
          videoUrl: mediaUrl, // Assign resolved URL
          isFavorite: jsonItem['isFavorite'] ?? false,
          progress: jsonItem['progress'] ?? 0,
        );
      }).toList();
    } catch (e) {
      // Print the specific error to the console so we know which file failed
      // e.g. "Unable to load asset" means file missing/pubspec issue
      // e.g. "FormatException" means bad JSON
      print("🔴 ASSET LOAD ERROR [$path]: $e");

      // Return empty list so the app doesn't crash
      return [];
    }
  }
}
