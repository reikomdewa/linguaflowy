import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linguaflow/services/home_feed_cache_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/services/lesson_service.dart';
import 'package:linguaflow/services/hybrid_lesson_service.dart';

class LessonRepository {
  final LessonService _firestoreService;
  final HybridLessonService _localService;
    final HomeFeedCacheService _cacheService = HomeFeedCacheService();

  LessonRepository({
    required LessonService firestoreService,
    required HybridLessonService localService,
  })  : _firestoreService = firestoreService,
        _localService = localService;

  // ==========================================================
  // 1. INITIAL LOAD (CRASH PREVENTION APPLIED)
  // ==========================================================
    Future<List<LessonModel>> getCachedLessons(String userId, String languageCode) async {
    return await _cacheService.loadCachedFeed(userId, languageCode);
  }
  Future<List<LessonModel>> getAndSyncLessons(
    String userId,
    String languageCode, {
    int limit = 20, // <--- SAFETY: Only load 20 at start
  }) async {
    try {
      // Helper to handle Firestore failure gracefully (so app works offline)
      Future<List<LessonModel>> safeFirestoreFetch() async {
        try {
          return await _firestoreService.getLessons(
            userId, 
            languageCode, 
            limit: limit
          );
        } catch (e) {
          print("Firestore sync failed (using local only): $e");
          return [];
        }
      }

      // --- UPDATED: Added fetchStorybooks to the list ---
      final results = await Future.wait([
        safeFirestoreFetch(),                             // 0: User Cloud (Limited)
        _fetchUserLocalImports(userId, languageCode),     // 1: User Local
        _localService.fetchStandardLessons(languageCode), // 2: System Standard
        _localService.fetchNativeVideos(languageCode),    // 3: System Videos
        _localService.fetchTextBooks(languageCode),       // 4: System Books
        _localService.fetchBeginnerBooks(languageCode),   // 5: System Beginner
        _localService.fetchAudioLessons(languageCode),    // 6: System Audio
        _localService.fetchStorybooks(languageCode),      // 7: System Short Stories (NEW)
      ]);

      final userLessons = results[0];
      final localImports = results[1];

      // Flatten system lessons (Include Index 7 now)
      final systemLessons = [
        ...results[2],
        ...results[3],
        ...results[4],
        ...results[5],
        ...results[6],
        ...results[7], // <--- ADDED Short Stories
      ];

      // Merge Strategy: Use a Map to handle duplicates
      final Map<String, LessonModel> combinedMap = {};

      // Priority 1: System Content (Base)
      for (var lesson in systemLessons) combinedMap[lesson.id] = lesson;
      
      // Priority 2: User Cloud Content (Overwrites System if IDs match)
      for (var lesson in userLessons) combinedMap[lesson.id] = lesson;
      
      // Priority 3: Local Imports (Highest Priority - for offline edits)
      for (var lesson in localImports) combinedMap[lesson.id] = lesson;

      final allLessons = combinedMap.values.toList();
      
      // Sort by Newest First
      allLessons.sort((a, b) => b.createdAt.compareTo(a.createdAt));
 _cacheService.saveFeedToCache(userId, languageCode, allLessons);
      return allLessons;
    } catch (e) {
      print("Error in LessonRepository sync: $e");
      return [];
    }
  }
Future<List<LessonModel>> getCachedGenreLessons(String userId, String languageCode, String genreKey) async {
    return await _cacheService.loadGenreFeed(userId, languageCode, genreKey);
  }

  Future<void> cacheGenreLessons(String userId, String languageCode, String genreKey, List<LessonModel> lessons) async {
    await _cacheService.saveGenreFeed(userId, languageCode, genreKey, lessons);
  }
  // ==========================================================
  // 2. PAGINATION LOGIC (INFINITE SCROLL)
  // ==========================================================

  /// Call this when the user scrolls to the bottom of the main feed
  Future<List<LessonModel>> fetchMoreUserLessons(
    String userId,
    String languageCode,
    LessonModel lastLesson, 
    {int limit = 20}
  ) async {
    // We only paginate Cloud lessons. Local lessons are assumed to be loaded.
    if (lastLesson.isLocal) {
      return []; 
    }

    try {
      return await _firestoreService.getMoreLessons(
        userId,
        languageCode,
        lastLesson, 
        limit: limit,
      );
    } catch (e) {
      print("Error fetching more lessons: $e");
      return [];
    }
  }

  /// Call this for Horizontal Lists (e.g. "Load more Videos")
  Future<List<LessonModel>> fetchPagedCategory(
    String languageCode,
    String type, // e.g. 'video', 'audio', 'text'
    {LessonModel? lastLesson, int limit = 10}
  ) async {
    return await _localService.fetchPagedSystemLessons(
      languageCode, 
      type, 
      lastLesson: lastLesson, 
      limit: limit
    );
  }

  /// Call this for GENRE Lists (e.g. "History", "Science")
  Future<List<LessonModel>> fetchPagedGenreLessons(
    String languageCode,
    String genreKey, {
    LessonModel? lastLesson,
    int limit = 10,
  }) async {
    // Note: You must ensure `fetchPagedGenreLessons` exists in LessonService
    // as discussed in previous steps.
    return await _firestoreService.fetchPagedGenreLessons(
      languageCode,
      genreKey,
      lastLesson,
      limit: limit,
    );
  }

  // ==========================================================
  // 3. CRUD OPERATIONS
  // ==========================================================

  Future<void> saveOrUpdateLesson(LessonModel lesson) async {
    if (lesson.isLocal) {
      await _saveLocalImportMetadata(lesson);
      return;
    }

    try {
      if (lesson.id.isEmpty) {
        final String newId = FirebaseFirestore.instance.collection('lessons').doc().id;
        final newLesson = lesson.copyWith(id: newId);
        await _firestoreService.createLesson(newLesson);
      } else {
        await _firestoreService.updateLesson(lesson);
      }
    } catch (e) {
      final localOverride = lesson.copyWith(isLocal: true);
      await _saveLocalImportMetadata(localOverride);
    }
  }

  Future<void> deleteLesson(LessonModel lesson) async {
    try {
      if (lesson.isLocal) {
        await _deleteLocalImportMetadata(lesson.id);
      } else {
        await _firestoreService.deleteLesson(lesson.id);
      }
    } catch (e) {
      await _deleteLocalImportMetadata(lesson.id);
    }
  }

  // ==========================================================
  // 4. OPTIMIZED LOCAL STORAGE
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
          .where((json) => 
              json is Map<String, dynamic> && 
              json['id'] != null &&
              json['userId'] == userId && 
              json['language'] == languageCode
          )
          .map((json) => LessonModel.fromMap(json, json['id'].toString()))
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