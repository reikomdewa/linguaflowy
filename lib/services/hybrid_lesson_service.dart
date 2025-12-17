import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/transcript_line.dart';
import 'package:linguaflow/utils/logger.dart';

class HybridLessonService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ===========================================================================
  // 1. STANDARD FETCHERS (NOW LIMITED TO 20 TO PREVENT CRASH)
  // ===========================================================================

  /// Fetches standard text/video lessons (Guided)
  Future<List<LessonModel>> fetchStandardLessons(String languageCode) async {
    return _fetchHybrid(
       localPath: 'assets/guided_courses/lessons_$languageCode.json', 
       userId: 'system', // or 'system_guided' to distinguish them
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
    // 1. Run all fetchers in parallel (LIMIT APPLIED INSIDE _loadFromFirestore)
    final results = await Future.wait([
      // Local 1: LibriVox
      _loadFromAsset(
        'assets/audio_library/audio_$languageCode.json',
        languageCode,
        'system_librivox',
      ),
      // Local 2: Audiobooks
      _loadFromAsset(
        'assets/youtube_audio_library/audiobooks_$languageCode.json',
        languageCode,
        'system_audiobook',
      ),
      // Remote: Fetch limited amount of remote audio
      _loadFromFirestore(languageCode, [
        'system_librivox',
        'system_audiobook',
      ], limit: 20),
    ]);

    final localLibrivox = results[0];
    final localAudiobooks = results[1];
    final remoteAudio = results[2];

    // 2. Merge all Local
    final allLocal = [...localLibrivox, ...localAudiobooks];

    // 3. Merge with Remote and Deduplicate
    return _mergeAndDeduplicate(allLocal, remoteAudio);
  }

  // ===========================================================================
  // 2. NEW PAGINATION METHOD (FOR HORIZONTAL LISTS)
  // ===========================================================================

  /// Fetches the NEXT batch of system lessons for a specific category
  Future<List<LessonModel>> fetchPagedSystemLessons(
    String languageCode,
    String categoryType, {
    LessonModel? lastLesson,
    int limit = 10,
  }) async {
    List<String> targetUserIds;

    // --- UPDATED LOGIC ---
    if (categoryType == 'immersion') {
      targetUserIds = ['system_native'];
    } else if (categoryType == 'guided') {
      targetUserIds = ['system'];
    } else if (categoryType == 'audio') {
      targetUserIds = ['system_librivox', 'system_audiobook'];
    } else if (categoryType == 'book') {
      // MERGE STRATEGY: Combine Gutenberg, Beginner, and Storybooks into "Library"
      targetUserIds = [
        'system_gutenberg',
        'system_beginner',
        'system_storybooks',
      ];
    } else if (categoryType == 'story') {
      // Just the Storybooks (useful for Genre feeds)
      targetUserIds = ['system_storybooks'];
    } else {
      targetUserIds = ['system'];
    }

    try {
      var query = _firestore
          .collection('lessons')
          .where('language', isEqualTo: languageCode)
          .where('userId', whereIn: targetUserIds);

      // Apply Type Filters to prevent mixed content
      if (categoryType == 'immersion') {
        query = query.where('type', isEqualTo: 'video');
      }
      // Both 'book' and 'story' are strictly text
      else if (categoryType == 'book' || categoryType == 'story') {
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
        // Handle fallback if userId is missing in doc
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
        _loadFromFirestore(languageCode, [userId], limit: 20), // LIMIT APPLIED
      ]);

      final localList = results[0];
      final remoteList = results[1];

      return _mergeAndDeduplicate(localList, remoteList);
    } catch (e) {
      // If offline or file missing, return just local asset or empty
      return _loadFromAsset(localPath, languageCode, userId);
    }
  }

  List<LessonModel> _mergeAndDeduplicate(
    List<LessonModel> local,
    List<LessonModel> remote,
  ) {
    // 1. Create a map starting with local files
    final Map<String, LessonModel> lessonMap = {
      for (var item in local) item.id: item,
    };

    // 2. Add remote files ONLY if they don't exist in local
    // (We prioritize Local for speed, but Remote adds new content)
    for (var item in remote) {
      if (!lessonMap.containsKey(item.id)) {
        lessonMap[item.id] = item;
      }
    }

    return lessonMap.values.toList();
  }

  // --- LOCAL LOADER ---
  Future<List<LessonModel>> _loadFromAsset(
    String path,
    String languageCode,
    String defaultUserId,
  ) async {
    try {
      final String jsonString = await rootBundle.loadString(path);
      final List<dynamic> data = json.decode(jsonString);

      // OPTIMIZATION: Take only first 50 from JSON to save RAM on startup.
      // Pagination handles the rest via Firestore.
      return data
          .take(50)
          .map((item) => _mapJsonToLesson(item, languageCode, defaultUserId))
          .toList();
    } catch (e) {
      // File might not exist for this language, return empty
      return [];
    }
  }

  // --- FIRESTORE LOADER ---
  Future<List<LessonModel>> _loadFromFirestore(
    String languageCode,
    List<String> userIds, {
    int limit = 20, // Added Limit Parameter
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

  // --- SHARED MAPPER ---
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
      // Pass genre if available, specifically for short stories
      genre: jsonItem['genre'] ?? 'general',
    );
  }

  DateTime _parseDate(dynamic date) {
    if (date == null) return DateTime.now();
    if (date is Timestamp) return date.toDate();
    if (date is String) return DateTime.tryParse(date) ?? DateTime.now();
    return DateTime.now();
  }
}
