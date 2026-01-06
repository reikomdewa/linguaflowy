import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <--- ADD THIS
import 'package:flutter/foundation.dart';
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
  }) : _firestoreService = firestoreService,
       _localService = localService;

  // ==========================================================
  // 1. INITIAL LOAD
  // ==========================================================
  Future<List<LessonModel>> getCachedLessons(
    String userId,
    String languageCode,
  ) async {
    return await _cacheService.loadCachedFeed(userId, languageCode);
  }

  Future<List<LessonModel>> fetchLessonsBySeries(
    String languageCode,
    String seriesId,
  ) async {
    try {
      final standard = await _localService.fetchStandardLessons(languageCode);
      final native = await _localService.fetchNativeVideos(languageCode);
      final audio = await _localService.fetchAudioLessons(languageCode);

      final allSystem = [...standard, ...native, ...audio];

      final seriesLessons = allSystem
          .where((l) => l.seriesId == seriesId)
          .toList();
      seriesLessons.sort(
        (a, b) => (a.seriesIndex ?? 0).compareTo(b.seriesIndex ?? 0),
      );

      return seriesLessons;
    } catch (e) {
      print("Error fetching series: $e");
      return [];
    }
  }

  Future<List<LessonModel>> getAndSyncLessons(
    String userId,
    String languageCode, {
    int limit = 20,
  }) async {
    try {
      // --- HELPER: Handle Firestore failure or Access Denied gracefully ---
      Future<List<LessonModel>> safeFirestoreFetch() async {
        // 1. CHECK AUTH: Don't call Firestore if we are a Guest or ID mismatch
        final currentUser = FirebaseAuth.instance.currentUser;

        // If not logged in, OR the requested userId doesn't match the auth token
        if (currentUser == null || currentUser.uid != userId) {
          // This prevents the [permission-denied] error for Guests
          return [];
        }

        try {
          return await _firestoreService.getLessons(
            userId,
            languageCode,
            limit: limit,
          );
        } catch (e) {
          print("Firestore sync failed (using local only): $e");
          return [];
        }
      }

      // Run fetches in parallel
      final results = await Future.wait([
        safeFirestoreFetch(), // 0: User Cloud (Safe guarded now)
        _fetchUserLocalImports(userId, languageCode), // 1: User Local
        _localService.fetchStandardLessons(languageCode), // 2
        _localService.fetchNativeVideos(languageCode), // 3
        _localService.fetchTextBooks(languageCode), // 4
        _localService.fetchBeginnerBooks(languageCode), // 5
        _localService.fetchAudioLessons(languageCode), // 6
      ]);

      final userLessons = results[0];
      final localImports = results[1];

      // Flatten system lessons
      final systemLessons = [
        ...results[2],
        ...results[3],
        ...results[4],
        ...results[5],
        ...results[6],
        ...results[7],
      ];

      final Map<String, LessonModel> combinedMap = {};

      // 1. Load System Content
      for (var lesson in systemLessons) {
        combinedMap[lesson.id] = lesson;
      }

      // 2. Merge User Cloud Content
      for (var userLesson in userLessons) {
        if (combinedMap.containsKey(userLesson.id)) {
          final systemVer = combinedMap[userLesson.id]!;
          combinedMap[userLesson.id] = userLesson.mergeSystemData(systemVer);
        } else {
          combinedMap[userLesson.id] = userLesson;
        }
      }

      // 3. Priority 3: Local Imports
      for (var lesson in localImports) {
        combinedMap[lesson.id] = lesson;
      }

      final allLessons = combinedMap.values.toList();
      allLessons.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _cacheService.saveFeedToCache(userId, languageCode, allLessons);

      return allLessons;
    } catch (e) {
      print("Error in LessonRepository sync: $e");
      return [];
    }
  }

  // ==========================================================
  // 2. PAGINATION & REST OF CLASS
  // ==========================================================

  Future<List<LessonModel>> fetchMoreUserLessons(
    String userId,
    String languageCode,
    LessonModel lastLesson, {
    int limit = 20,
  }) async {
    // Determine target IDs based on who is logged in
    final currentUser = FirebaseAuth.instance.currentUser;
    final bool isLoggedIn = currentUser != null && currentUser.uid == userId;

    // If logged in, include their ID. If guest, only fetch system.
    final targetIds = isLoggedIn
        ? [userId, 'system', 'system_course', 'system_native']
        : ['system', 'system_course', 'system_native'];

    try {
      return await _firestoreService.getMoreUnifiedLessons(
        targetIds,
        languageCode,
        lastLesson,
        limit: limit,
      );
    } catch (e) {
      print("Error fetching more unified lessons: $e");
      return [];
    }
  }

  Future<List<LessonModel>> getCachedGenreLessons(
    String userId,
    String languageCode,
    String genreKey,
  ) async {
    return await _cacheService.loadGenreFeed(userId, languageCode, genreKey);
  }

  Future<void> cacheGenreLessons(
    String userId,
    String languageCode,
    String genreKey,
    List<LessonModel> lessons,
  ) async {
    await _cacheService.saveGenreFeed(userId, languageCode, genreKey, lessons);
  }

  Future<List<LessonModel>> fetchPagedCategory(
    String languageCode,
    String type, {
    LessonModel? lastLesson,
    int limit = 10,
  }) async {
    return await _localService.fetchPagedSystemLessons(
      languageCode,
      type,
      lastLesson: lastLesson,
      limit: limit,
    );
  }

  Future<List<LessonModel>> fetchPagedGenreLessons(
    String languageCode,
    String genreKey, {
    LessonModel? lastLesson,
    int limit = 10,
  }) async {
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
    // Only allow cloud saving if logged in
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Force local save for guests
      await _saveLocalImportMetadata(lesson);
      return;
    }

    if (lesson.isLocal && !lesson.isPublic) {
      await _saveLocalImportMetadata(lesson);
      return;
    }

    try {
      final lessonToUpload = lesson.copyWith(isLocal: false);

      if (lesson.id.isEmpty) {
        await addLesson(lessonToUpload);
      } else {
        await FirebaseFirestore.instance
            .collection('lessons')
            .doc(lesson.id)
            .set(lessonToUpload.toMap(), SetOptions(merge: true));
      }

      if (lesson.isLocal) {
        await _deleteLocalImportMetadata(lesson.id);
      }
    } catch (e) {
      print("Error saving/updating to cloud: $e");
      final localOverride = lesson.copyWith(isLocal: true);
      await _saveLocalImportMetadata(localOverride);
      rethrow;
    }
  }

  Future<void> deleteLesson(LessonModel lesson) async {
    try {
      if (!lesson.isLocal || lesson.isPublic) {
        await _firestoreService.deleteLesson(lesson.id);
      }
      await _deleteLocalImportMetadata(lesson.id);
    } catch (e) {
      await _deleteLocalImportMetadata(lesson.id);
    }
  }

  Future<void> addLesson(LessonModel lesson) async {
    if (lesson.isLocal && !lesson.isPublic) {
      await _saveLocalImportMetadata(lesson);
      return;
    }

    try {
      String docId = lesson.id;
      if (docId.isEmpty) {
        docId = FirebaseFirestore.instance.collection('lessons').doc().id;
      }

      final lessonToSave = lesson.copyWith(id: docId, isLocal: false);

      await FirebaseFirestore.instance
          .collection('lessons')
          .doc(docId)
          .set(lessonToSave.toMap());

      if (lesson.isLocal) {
        await _deleteLocalImportMetadata(lesson.id);
      }
    } catch (e) {
      print("Error adding lesson: $e");
      throw Exception("Failed to add lesson");
    }
  }

  // ==========================================================
  // 4. LOCAL STORAGE (FILES)
  // ==========================================================

  Future<File> get _localJsonFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/user_imported_lessons.json');
  }

  Future<List<LessonModel>> _fetchUserLocalImports(
    String userId,
    String languageCode,
  ) async {
    // Web doesn't support dart:io File. Return empty.
    if (kIsWeb) return [];

    try {
      final file = await _localJsonFile;
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      if (content.isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(content);

      return jsonList
          .where(
            (json) =>
                json is Map<String, dynamic> &&
                json['id'] != null &&
                json['userId'] == userId &&
                json['language'] == languageCode,
          )
          .map((json) => LessonModel.fromMap(json, json['id'].toString()))
          .map((l) => l.copyWith(isLocal: true))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _saveLocalImportMetadata(LessonModel lesson) async {
    if (kIsWeb) return; // Web doesn't support local file saving yet

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
      // log error
    }
  }

  Future<void> _deleteLocalImportMetadata(String lessonId) async {
    if (kIsWeb) return;

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
      // log error
    }
  }
}
