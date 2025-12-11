import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/services/lesson_service.dart';
import 'package:linguaflow/services/hybrid_lesson_service.dart';

class LessonRepository {
  final LessonService _firestoreService;
  final HybridLessonService _localService;

  LessonRepository({
    required LessonService firestoreService,
    required HybridLessonService localService,
  })  : _firestoreService = firestoreService,
        _localService = localService;

  // --- MAIN SYNC FUNCTION ---
  Future<List<LessonModel>> getAndSyncLessons(String userId, String languageCode) async {
    try {
      final results = await Future.wait([
        // 1. Cloud Lessons
        _firestoreService.getLessons(userId, languageCode),
        // 2. User Local Imports (Fixed)
        _fetchUserLocalImports(userId, languageCode),
        // 3. System Assets
        _localService.fetchStandardLessons(languageCode),
        _localService.fetchNativeVideos(languageCode),
        _localService.fetchTextBooks(languageCode),
        _localService.fetchBeginnerBooks(languageCode),
        _localService.fetchAudioLessons(languageCode),
      ]);

      final userLessons = results[0] as List<LessonModel>;
      final localImports = results[1] as List<LessonModel>;
      
      final systemLessons = [
        ...results[2] as List<LessonModel>,
        ...results[3] as List<LessonModel>,
        ...results[4] as List<LessonModel>,
        ...results[5] as List<LessonModel>,
        ...results[6] as List<LessonModel>,
      ];

      final Map<String, LessonModel> combinedMap = {};

      // System Content
      for (var lesson in systemLessons) combinedMap[lesson.id] = lesson;
      // User Cloud Content
      for (var lesson in userLessons) combinedMap[lesson.id] = lesson;
      // User Local Content (Overrides others if IDs match)
      for (var lesson in localImports) combinedMap[lesson.id] = lesson;

      final allLessons = combinedMap.values.toList();
      allLessons.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return allLessons;
    } catch (e) {
      print("Error in LessonRepository sync: $e");
      return [];
    }
  }

  // --- SAVE / UPDATE ---
  Future<void> saveOrUpdateLesson(LessonModel lesson) async {
    if (lesson.isLocal) {
      await _saveLocalImportMetadata(lesson);
    } else {
      if (lesson.id.isEmpty) {
        await _firestoreService.createLesson(lesson);
      } else {
        await _firestoreService.updateLesson(lesson);
      }
    }
  }

  // --- DELETE ---
  Future<void> deleteLesson(LessonModel lesson) async {
    if (lesson.isLocal) {
      await _deleteLocalImportMetadata(lesson.id);
      // Optional: Clean up actual media files here if desired
    } else {
      await _firestoreService.deleteLesson(lesson.id);
    }
  }

  // ==========================================================
  // LOCAL JSON STORAGE (The Fixes are here)
  // ==========================================================

  Future<File> get _localJsonFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/user_imported_lessons.json');
  }

  Future<List<LessonModel>> _fetchUserLocalImports(String userId, String languageCode) async {
    try {
      final file = await _localJsonFile;
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      if (content.isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(content);

      return jsonList
          // FIX 1: Filter out bad data where 'id' might be missing
          .where((json) => json is Map<String, dynamic> && json['id'] != null)
          .map((json) {
             // FIX 2: Safely parse to model
             return LessonModel.fromMap(json, json['id'].toString());
          })
          .where((l) => l.userId == userId && l.language == languageCode)
          .map((l) => l.copyWith(isLocal: true)) 
          .toList();
    } catch (e) {
      print("Error reading local imports: $e");
      return [];
    }
  }

  Future<void> _saveLocalImportMetadata(LessonModel lesson) async {
    try {
      final file = await _localJsonFile;
      List<LessonModel> currentLessons = [];

      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final List<dynamic> jsonList = jsonDecode(content);
          currentLessons = jsonList
              .where((json) => json['id'] != null)
              .map((j) => LessonModel.fromMap(j, j['id'].toString()))
              .toList();
        }
      }

      final index = currentLessons.indexWhere((l) => l.id == lesson.id);
      if (index != -1) {
        currentLessons[index] = lesson;
      } else {
        currentLessons.add(lesson);
      }

      // FIX 3: Explicitly add 'id' to the map before saving
      final jsonList = currentLessons.map((l) {
        final map = l.toMap();
        map['id'] = l.id; // <--- This prevents the Null error on next read
        return map;
      }).toList();

      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      print("Error saving local import: $e");
    }
  }

  Future<void> _deleteLocalImportMetadata(String lessonId) async {
    try {
      final file = await _localJsonFile;
      if (!await file.exists()) return;

      final content = await file.readAsString();
      if (content.isEmpty) return;

      final List<dynamic> jsonList = jsonDecode(content);
      final updatedList = jsonList.where((item) => item['id'] != lessonId).toList();
      
      await file.writeAsString(jsonEncode(updatedList));
    } catch (e) {
      print("Error deleting local import: $e");
    }
  }
}