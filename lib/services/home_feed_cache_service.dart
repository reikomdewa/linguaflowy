import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:linguaflow/models/lesson_model.dart';

class HomeFeedCacheService {
  static const String _fileName = 'home_feed_cache.json';
  
  // PRO TIP: Increment this number if you change data structure or filtering logic.
  // This prevents users from seeing "poisoned" or broken data after an update.
  static const int _currentCacheVersion = 1;

  Future<File> get _cacheFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  /// 1. READ CACHE
  Future<List<LessonModel>> loadCachedFeed(String userId, String languageCode) async {
    try {
      final file = await _cacheFile;
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      if (content.isEmpty) return [];

      final Map<String, dynamic> data = jsonDecode(content);

      // --- CHECK 1: VERSIONING (The Pro Tip) ---
      // If the saved version doesn't match the code version, ignore the cache.
      final int savedVersion = data['version'] ?? 0;
      if (savedVersion != _currentCacheVersion) {
        // print("⚠️ Old cache version detected ($savedVersion). Ignoring.");
        return [];
      }

      // --- CHECK 2: USER & LANGUAGE ---
      // Prevent showing French cache when user switched to Spanish or logged out
      if (data['userId'] != userId || data['language'] != languageCode) {
        return [];
      }

      final List<dynamic> jsonList = data['lessons'] ?? [];
      
      return jsonList
          .map((json) => LessonModel.fromMap(json, json['id'] ?? ''))
          .toList();
    } catch (e) {
      // debugPrint("⚠️ Cache read error: $e");
      return [];
    }
  }

  /// 2. WRITE CACHE
  Future<void> saveFeedToCache(String userId, String languageCode, List<LessonModel> lessons) async {
    try {
      final file = await _cacheFile;
      
      // --- FIX: INTELLIGENT CACHING ---
      // Instead of just taking the top 30 (which might be all videos),
      // we explicitly grab a mix of categories to ensure the UI looks full immediately.
      
      List<LessonModel> itemsToCache = [];

      // 1. Grab top 10 System/Guided lessons (Priority)
      itemsToCache.addAll(
        lessons.where((l) => l.userId == 'system').take(10)
      );

      // 2. Grab top 10 Immersion/Native videos
      itemsToCache.addAll(
        lessons.where((l) => l.userId == 'system_native').take(10)
      );
      
      // 3. Grab top 5 User Imported lessons (Most important for user)
      itemsToCache.addAll(
        lessons.where((l) => !l.userId.startsWith('system')).take(5)
      );

      // 4. Fill the rest with whatever is newest until we hit 50 items
      final existingIds = itemsToCache.map((e) => e.id).toSet();
      final remaining = lessons
          .where((l) => !existingIds.contains(l.id))
          .take(50 - itemsToCache.length);
          
      itemsToCache.addAll(remaining);

      // 5. Re-sort them by date so they display correctly in the UI
      itemsToCache.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final Map<String, dynamic> data = {
        'version': _currentCacheVersion, // <--- Saving Version
        'timestamp': DateTime.now().toIso8601String(),
        'userId': userId,
        'language': languageCode,
        'lessons': itemsToCache.map((l) => l.toMap()).toList(),
      };

      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      // debugPrint("⚠️ Cache write error: $e");
    }
  }
  
  /// 3. CLEAR CACHE (Optional, e.g. on Logout)
  Future<void> clearCache() async {
    final file = await _cacheFile;
    if (await file.exists()) {
      await file.delete();
    }
  }
}