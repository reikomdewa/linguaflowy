import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/transcript_line.dart';
import 'package:linguaflow/utils/logger.dart';

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

  /// Fetches Graded Short Stories (Global Storybooks)
  Future<List<LessonModel>> fetchStorybooks(String languageCode) async {
    return _fetchHybrid(
      localPath: 'assets/storybooks_lessons/storybooks_$languageCode.json',
      userId: 'system_storybooks',
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
    int limit = 10,
  }) async {
    List<String> targetUserIds;

    if (categoryType == 'immersion') {
      targetUserIds = ['system_native'];
    } else if (categoryType == 'guided') {
      targetUserIds = ['system'];
    } else if (categoryType == 'audio') {
      targetUserIds = ['system_librivox', 'system_audiobook'];
    } else if (categoryType == 'book') {
      targetUserIds = [
        'system_gutenberg',
        'system_beginner',
        'system_storybooks',
      ];
    } else if (categoryType == 'story') {
      targetUserIds = ['system_storybooks'];
    } else {
      targetUserIds = ['system'];
    }

    try {
      var query = _firestore
          .collection('lessons')
          .where('language', isEqualTo: languageCode)
          .where('userId', whereIn: targetUserIds);

      if (categoryType == 'immersion') {
        query = query.where('type', isEqualTo: 'video');
      } else if (categoryType == 'book' || categoryType == 'story') {
        query = query.where('type', isEqualTo: 'text');
      }

      query = query.orderBy('createdAt', descending: true);

      if (lastLesson != null) {
        query = query.startAfter([Timestamp.fromDate(lastLesson.createdAt)]);
      }

      final snapshot = await query.limit(limit).get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        String foundUserId = data['userId'] ?? targetUserIds.first;
        return _mapJsonToLesson(data, languageCode, foundUserId);
      }).toList();
    } catch (e) {
      printLog("Pagination Error ($categoryType): $e");
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
    int limit = 20,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('lessons')
          .where('language', isEqualTo: languageCode)
          .where('userId', whereIn: userIds)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return _mapJsonToLesson(data, languageCode, userIds.first);
      }).toList();
    } catch (e) {
      printLog("🔥 FIRESTORE ERROR (Language: $languageCode): $e");
      return [];
    }
  }

  // ===========================================================================
  // 🔴 FIXED MAPPING METHOD
  // ===========================================================================
  LessonModel _mapJsonToLesson(
    Map<String, dynamic> jsonItem,
    String languageCode,
    String defaultUserId,
  ) {
    final id =
        jsonItem['id']?.toString() ??
        'unknown_${DateTime.now().millisecondsSinceEpoch}';

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
      sentences:
          (jsonItem['sentences'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      transcript:
          (jsonItem['transcript'] as List<dynamic>?)
              ?.map((e) => TranscriptLine.fromMap(e))
              .toList() ??
          [],
      createdAt: _parseDate(jsonItem['createdAt']),
      imageUrl: jsonItem['imageUrl'],
      type: jsonItem['type'] ?? 'text',
      difficulty: jsonItem['difficulty'] ?? 'intermediate',
      videoUrl: mediaUrl,
      isFavorite: jsonItem['isFavorite'] ?? false,
      progress: jsonItem['progress'] ?? 0,
      genre: jsonItem['genre'] ?? 'general',

      // ✅ ADDED THESE LINES TO MAP PLAYLIST DATA ✅
      seriesId: jsonItem['seriesId']?.toString(),
      seriesTitle: jsonItem['seriesTitle']?.toString(),
      seriesIndex: int.tryParse(jsonItem['seriesIndex']?.toString() ?? ''),
    );
  }

  DateTime _parseDate(dynamic date) {
    if (date == null) return DateTime.now();
    if (date is Timestamp) return date.toDate();
    if (date is String) return DateTime.tryParse(date) ?? DateTime.now();
    return DateTime.now();
  }
}