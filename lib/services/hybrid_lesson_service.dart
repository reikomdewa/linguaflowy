import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/transcript_line.dart';

class HybridLessonService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ===========================================================================
  // 1. STANDARD FETCHERS
  // ===========================================================================

  /// Fetches standard text/video lessons (Guided)
  Future<List<LessonModel>> fetchStandardLessons(String languageCode) async {
    return _fetchHybrid(
      localPath: 'assets/guided_courses/lessons_$languageCode.json',
      userId: 'system',
      languageCode: languageCode,
    );
  }

  /// Fetches native trending videos
  Future<List<LessonModel>> fetchNativeVideos(String languageCode) async {
    return _fetchHybrid(
      localPath: 'assets/native_videos/trending_$languageCode.json',
      userId: 'system_native',
      languageCode: languageCode,
    );
  }

  /// Fetches Gutenberg Books
  Future<List<LessonModel>> fetchTextBooks(String languageCode) async {
    return _fetchHybrid(
      localPath: 'assets/text_lessons/books_$languageCode.json',
      userId: 'system_gutenberg',
      languageCode: languageCode,
    );
  }

  /// Fetches Beginner Books
  Future<List<LessonModel>> fetchBeginnerBooks(String languageCode) async {
    return _fetchHybrid(
      localPath: 'assets/beginner_books/beginner_$languageCode.json',
      userId: 'system_beginner',
      languageCode: languageCode,
    );
  }


  /// Fetches Audio content (Combines LibriVox + YouTube Audiobooks)
  Future<List<LessonModel>> fetchAudioLessons(String languageCode) async {
    final results = await Future.wait([
      _loadFromAsset(
        'assets/audio_library/audio_$languageCode.json',
        languageCode,
        'system_librivox',
      ),
      _loadFromAsset(
        'assets/youtube_audio_library/audiobooks_$languageCode.json',
        languageCode,
        'system_audiobook',
      ),
      _loadFromFirestore(languageCode, [
        'system_librivox',
        'system_audiobook',
      ], limit: 20),
    ]);

    final localLibrivox = results[0];
    final localAudiobooks = results[1];
    final remoteAudio = results[2];

    final allLocal = [...localLibrivox, ...localAudiobooks];
    return _mergeAndDeduplicate(allLocal, remoteAudio);
  }

  // ===========================================================================
  // 2. PAGINATION METHOD
  // ===========================================================================

  Future<List<LessonModel>> fetchPagedSystemLessons(
    String languageCode,
    String categoryType, {
    LessonModel? lastLesson,
    int limit = 20, // Increased default limit
  }) async {
    List<String> targetUserIds;

    // Mapping UI Category -> Database User IDs
    if (categoryType == 'immersion' || categoryType == 'video') {
      targetUserIds = ['system_native'];
    } else if (categoryType == 'standard' || categoryType == 'guided') {
      targetUserIds = ['system', 'system_course'];
    } else if (categoryType == 'audio') {
      targetUserIds = ['system_librivox', 'system_audiobook'];
    } else if (categoryType == 'book') {
      targetUserIds = [
        'system_gutenberg',
        'system_beginner',
        'system_storybooks',
      ];
    } else {
      targetUserIds = ['system'];
    }

    try {
      var query = _firestore
          .collection('lessons')
          .where('language', isEqualTo: languageCode)
          .where('userId', whereIn: targetUserIds);

      query = query.orderBy('createdAt', descending: true);

      if (lastLesson != null) {
        // 🔥 THE FIX: Python uses ISO Strings. We MUST use a String for the cursor.
        // We also ensure we aren't passing a "local" ID that doesn't exist in DB
        final String lastDateString = lastLesson.createdAt
            .toUtc()
            .toIso8601String();
        query = query.startAfter([lastDateString]);
      }

      final snapshot = await query.limit(limit).get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return _mapJsonToLesson(
          data,
          languageCode,
          data['userId'] ?? targetUserIds.first,
        );
      }).toList();
    } catch (e) {
      print("🔥 Firestore Pagination Error: $e");
      return [];
    }
  }

  // ===========================================================================
  // 3. HELPER METHODS
  // ===========================================================================

  Future<List<LessonModel>> _fetchHybrid({
    required String localPath,
    required String userId,
    required String languageCode,
  }) async {
    try {
      final results = await Future.wait([
        _loadFromAsset(localPath, languageCode, userId),
        _loadFromFirestore(languageCode, [userId], limit: 20),
      ]);

      return _mergeAndDeduplicate(results[0], results[1]);
    } catch (e) {
      return _loadFromAsset(localPath, languageCode, userId);
    }
  }

  List<LessonModel> _mergeAndDeduplicate(
    List<LessonModel> local,
    List<LessonModel> remote,
  ) {
    final Map<String, LessonModel> lessonMap = {
      for (var item in local) item.id: item,
    };

    for (var item in remote) {
      if (!lessonMap.containsKey(item.id)) {
        lessonMap[item.id] = item;
      }
    }

    return lessonMap.values.toList();
  }

  Future<List<LessonModel>> _loadFromAsset(
    String path,
    String languageCode,
    String defaultUserId,
  ) async {
    try {
      final String jsonString = await rootBundle.loadString(path);
      final List<dynamic> data = json.decode(jsonString);

      return data
          .take(50) // Optimization: Limit local load for memory
          .map((item) => _mapJsonToLesson(item, languageCode, defaultUserId))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<LessonModel>> _loadFromFirestore(
    String languageCode,
    List<String> userIds, {
    int limit = 100, // Increased limit to see 2030 lessons better
  }) async {
    try {
      if (userIds.isEmpty) return [];

      final snapshot = await _firestore
          .collection('lessons')
          .where('language', isEqualTo: languageCode)
          .where('userId', whereIn: userIds)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      List<LessonModel> lessons = [];

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          // DO NOT print(data) or print(data) here!
          // Printing the raw map is what causes the Stack Overflow.

          final lesson = _mapJsonToLesson(
            data,
            languageCode,
            data['userId'] ?? userIds.first,
          );

          lessons.add(lesson);
        } catch (e) {
          continue;
        }
      }
      return lessons;
    } catch (e) {
      // Use a simple string for the error to avoid Stack Overflow
      print("🔥 FIRESTORE ERROR: Query failed for $userIds");
      return [];
    }
  }
  // 2. UPDATE YOUR MERGE LOGIC
  // In LessonRepository, your getAndSyncLessons currently trusts systemLessons (Local)
  // to be the "Base". If the local JSON is old and the Firebase is new,
  // we should prioritize Firebase metadata if the IDs match.

  // ===========================================================================
  // 🔴 FIXED MAPPING METHOD
  // ===========================================================================
  LessonModel _mapJsonToLesson(
    Map<String, dynamic> jsonItem,
    String languageCode,
    String defaultUserId,
  ) {
    // 1. Safe ID generation
    final id =
        jsonItem['id']?.toString() ??
        'unknown_${DateTime.now().millisecondsSinceEpoch}';

    // 2. Safe Media URL Handling (Check both possible names)
    String? mediaUrl =
        jsonItem['videoUrl']?.toString() ?? jsonItem['audioUrl']?.toString();
    if (mediaUrl != null && mediaUrl.isEmpty) mediaUrl = null;

    return LessonModel(
      id: id,
      userId: jsonItem['userId']?.toString() ?? defaultUserId,
      title: jsonItem['title']?.toString() ?? 'Untitled Lesson',
      language: jsonItem['language']?.toString() ?? languageCode,
      content: jsonItem['content']?.toString() ?? '',

      // 3. Safe List Handling (Prevents crash if sentences is null)
      sentences:
          (jsonItem['sentences'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],

      // 4. Safe Transcript Handling
      transcript:
          (jsonItem['transcript'] as List<dynamic>?)
              ?.map((e) => TranscriptLine.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],

      createdAt: _parseDate(jsonItem['createdAt']),
      imageUrl: jsonItem['imageUrl']?.toString() ?? "",
      type: jsonItem['type']?.toString() ?? 'video',
      difficulty: jsonItem['difficulty']?.toString() ?? 'intermediate',
      videoUrl: mediaUrl,
      isFavorite: jsonItem['isFavorite'] == true, // Explicit boolean check
      progress: (jsonItem['progress'] is num)
          ? (jsonItem['progress'] as num).toInt()
          : 0,
      // 5. Safe Playlist Data (The likely culprit "2")
      // We use tryParse and nullable types to ensure no crash here
      seriesId: jsonItem['seriesId']?.toString(),
      seriesTitle: jsonItem['seriesTitle']?.toString(),
      seriesIndex: jsonItem['seriesIndex'] != null
          ? int.tryParse(jsonItem['seriesIndex'].toString())
          : null,
    );
  }

  DateTime _parseDate(dynamic date) {
    try {
      if (date == null) return DateTime.now();
      if (date is Timestamp) return date.toDate();
      if (date is String) {
        // Handle ISO format from Python or simple strings
        return DateTime.tryParse(date) ?? DateTime.now();
      }
      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }
}
