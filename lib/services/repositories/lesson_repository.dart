import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  }) : _firestoreService = firestoreService,
       _localService = localService;

  // --- MAIN SYNC FUNCTION ---
  Future<List<LessonModel>> getAndSyncLessons(
    String userId,
    String languageCode,
  ) async {
    try {
      final results = await Future.wait([
        _firestoreService.getLessons(userId, languageCode),
        _fetchUserLocalImports(userId, languageCode),
        _localService.fetchStandardLessons(languageCode),
        _localService.fetchNativeVideos(languageCode),
        _localService.fetchTextBooks(languageCode),
        _localService.fetchBeginnerBooks(languageCode),
        _localService.fetchAudioLessons(languageCode),
      ]);

      final userLessons = results[0];
      final localImports = results[1];

      final systemLessons = [
        ...results[2],
        ...results[3],
        ...results[4],
        ...results[5],
        ...results[6],
      ];

      final Map<String, LessonModel> combinedMap = {};

      for (var lesson in systemLessons) {
        combinedMap[lesson.id] = lesson;
      }
      for (var lesson in userLessons) {
        combinedMap[lesson.id] = lesson;
      }
      for (var lesson in localImports) {
        combinedMap[lesson.id] = lesson;
      }

      final allLessons = combinedMap.values.toList();
      allLessons.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return allLessons;
    } catch (e) {
      // print("Error in LessonRepository sync: $e");
      return [];
    }
  }

  // --- SAVE / UPDATE ---
  Future<void> saveOrUpdateLesson(LessonModel lesson) async {
    if (lesson.isLocal) {
      await _saveLocalImportMetadata(lesson);
      return;
    }

    try {
      if (lesson.id.isEmpty) {
        // Generate valid ID for new Cloud Copy
        final String newId = FirebaseFirestore.instance
            .collection('lessons')
            .doc()
            .id;
        final newLesson = lesson.copyWith(id: newId);
        await _firestoreService.createLesson(newLesson);
      } else {
        await _firestoreService.updateLesson(lesson);
      }
    } catch (e) {
      // Fallback to local storage on failure
      final localOverride = lesson.copyWith(isLocal: true);
      await _saveLocalImportMetadata(localOverride);
    }
  }

  // --- DELETE ---
  Future<void> deleteLesson(LessonModel lesson) async {
    try {
      if (lesson.isLocal) {
        await _deleteLocalImportMetadata(lesson.id);
      } else {
        await _firestoreService.deleteLesson(lesson.id);
      }
    } catch (e) {
      // Ensure local cleanup even if cloud fails
      await _deleteLocalImportMetadata(lesson.id);
    }
  }

  // ==========================================================
  // LOCAL JSON STORAGE
  // ==========================================================

  Future<File> get _localJsonFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/user_imported_lessons.json');
  }

  Future<List<LessonModel>> _fetchUserLocalImports(
    String userId,
    String languageCode,
  ) async {
    try {
      final file = await _localJsonFile;
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      if (content.isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(content);

      return jsonList
          .where((json) => json is Map<String, dynamic> && json['id'] != null)
          .map((json) => LessonModel.fromMap(json, json['id'].toString()))
          // STRICT FILTER: Only allow lessons belonging to this user
          .where((l) => l.userId == userId && l.language == languageCode)
          .map((l) => l.copyWith(isLocal: true))
          .toList();
    } catch (e) {
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

      LessonModel lessonToSave = lesson;
      if (lessonToSave.id.isEmpty) {
        lessonToSave = lessonToSave.copyWith(
          id: "local_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}",
        );
      }

      final index = currentLessons.indexWhere((l) => l.id == lessonToSave.id);
      if (index != -1) {
        currentLessons[index] = lessonToSave;
      } else {
        currentLessons.add(lessonToSave);
      }

      final jsonList = currentLessons.map((l) {
        final map = l.toMap();
        map['id'] = l.id;
        return map;
      }).toList();

      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      // print("Error saving local import: $e");
    }
  }

  Future<void> _deleteLocalImportMetadata(String lessonId) async {
    try {
      final file = await _localJsonFile;
      if (!await file.exists()) return;

      final content = await file.readAsString();
      if (content.isEmpty) return;

      final List<dynamic> jsonList = jsonDecode(content);
      final updatedList = jsonList
          .where((item) => item['id'] != lessonId)
          .toList();

      await file.writeAsString(jsonEncode(updatedList));
    } catch (e) {
      // print("Error deleting local import: $e");
    }
  }
}
