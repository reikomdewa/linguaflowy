import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeFeedCacheService {
  static const String _homeFileName = 'home_feed_cache.json';
  static const int _currentCacheVersion = 1;
  Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    // This clears only the keys starting with your prefix
    final allKeys = prefs.getKeys();
    for (String key in allKeys) {
      if (key.startsWith('home_feed_') || key.startsWith('lesson_cache_')) {
        await prefs.remove(key);
      }
    }
    print("🧹 All lesson cache cleared.");
  }

  Future<File> _getFile(String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$filename');
  }

  // ===========================================================================
  // NEW: HELPER TO PREVENT INVALID FILENAMES
  // ===========================================================================

  // ===========================================================================
  // PRIVATE GENERIC HELPERS (Unchanged)
  // ===========================================================================

  Future<List<LessonModel>> _loadFromFile(
    String filename,
    String userId,
    String languageCode,
  ) async {
    try {
      final file = await _getFile(filename);
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      if (content.isEmpty) return [];

      final Map<String, dynamic> data = jsonDecode(content);

      if ((data['version'] ?? 0) != _currentCacheVersion) return [];
      if (data['userId'] != userId || data['language'] != languageCode) {
        return [];
      }

      final List<dynamic> jsonList = data['lessons'] ?? [];

      return jsonList
          .map((json) => LessonModel.fromMap(json, json['id'] ?? ''))
          .toList();
    } catch (e) {
      // debugPrint("Read Error: $e");
      return [];
    }
  }

  Future<void> _saveToFile(
    String filename,
    String userId,
    String languageCode,
    List<LessonModel> lessons,
  ) async {
    try {
      final file = await _getFile(filename);

      final Map<String, dynamic> data = {
        'version': _currentCacheVersion,
        'timestamp': DateTime.now().toIso8601String(),
        'userId': userId,
        'language': languageCode,
        'lessons': lessons.map((l) => l.toMap()).toList(),
      };

      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      // debugPrint("Write Error: $e");
    }
  }

  // ===========================================================================
  // HOME FEED METHODS
  // ===========================================================================

  Future<List<LessonModel>> loadCachedFeed(String userId, String languageCode) {
    return _loadFromFile(_homeFileName, userId, languageCode);
  }

  Future<void> saveFeedToCache(
    String userId,
    String languageCode,
    List<LessonModel> lessons,
  ) async {
    List<LessonModel> itemsToCache = [];

    itemsToCache.addAll(lessons.where((l) => l.userId == 'system').take(10));
    itemsToCache.addAll(
      lessons.where((l) => l.userId == 'system_native').take(10),
    );
    itemsToCache.addAll(
      lessons.where((l) => !l.userId.startsWith('system')).take(5),
    );

    final existingIds = itemsToCache.map((e) => e.id).toSet();
    final remaining = lessons
        .where((l) => !existingIds.contains(l.id))
        .take(50 - itemsToCache.length);

    itemsToCache.addAll(remaining);
    itemsToCache.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    await _saveToFile(_homeFileName, userId, languageCode, itemsToCache);
  }

  Future<List<LessonModel>> loadGenreFeed(
    String userId,
    String languageCode,
    String genreKey,
  ) {
    // Ensure we are using a safe filename, regardless of what key is passed
    final filename = _generateSafeGenreFilename(genreKey);
    return _loadFromFile(filename, userId, languageCode);
  }

  Future<void> saveGenreFeed(
    String userId,
    String languageCode,
    String genreKey,
    List<LessonModel> lessons,
  ) async {
    final filename = _generateSafeGenreFilename(genreKey);

    // Cache top 20
    final itemsToCache = lessons.take(20).toList();
    await _saveToFile(filename, userId, languageCode, itemsToCache);
  }

  /// Converts keys into safe filenames
  /// Input: "literature" -> "genre_literature_cache.json" (Perfect)
  /// Input: "Books & Literature" -> "genre_books___literature_cache.json" (Safe fallback)
  String _generateSafeGenreFilename(String genreKey) {
    final safeKey = genreKey.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '_',
    ); // Replace non-alphanumeric with _

    return 'genre_${safeKey}_cache.json';
  }

  Future<void> clearCache() async {
    try {
      final directory = await getApplicationDocumentsDirectory();

      // Using listSync() without recursive true.
      // Safe filenames ensure we don't accidentally create subdirectories.
      final files = directory.listSync().where((entity) {
        return entity is File &&
            (entity.path.endsWith('home_feed_cache.json') ||
                // Checks for our new safe format (and matches old format if simple)
                (entity.path.contains('genre_') &&
                    entity.path.endsWith('_cache.json')));
      });

      for (var entity in files) {
        await entity.delete();
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }
}
