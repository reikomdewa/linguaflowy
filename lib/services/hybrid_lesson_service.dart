import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/transcript_line.dart';

class HybridLessonService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches standard text/video lessons (Guided)
  Future<List<LessonModel>> fetchStandardLessons(String languageCode) async {
    return _fetchHybrid(
      localPath: 'assets/guided/lessons_$languageCode.json',
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
  /// This is unique because it combines two local sources + firestore audio
  Future<List<LessonModel>> fetchAudioLessons(String languageCode) async {
    // 1. Run all fetchers in parallel
    final results = await Future.wait([
      // Local 1: LibriVox
      _loadFromAsset('assets/audio_library/audio_$languageCode.json', languageCode, 'system_librivox'),
      // Local 2: Audiobooks
      _loadFromAsset('assets/youtube_audio_library/audiobooks_$languageCode.json', languageCode, 'system_audiobook'),
      // Remote: Fetch ANY audio type for this language
      _loadFromFirestore(languageCode, ['system_librivox', 'system_audiobook']),
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
  // 🛠️ HELPER METHODS
  // ===========================================================================

  /// Orchestrates the Local + Remote fetch and merge
 // Inside HybridLessonService

Future<List<LessonModel>> _fetchHybrid({
  required String localPath,
  required String userId,
  required String languageCode,
}) async {
  try {
    final results = await Future.wait([
      _loadFromAsset(localPath, languageCode, userId),
      _loadFromFirestore(languageCode, [userId]),
    ]);

    final localList = results[0];
    final remoteList = results[1];

    
    // Optional: Print names of remote lessons to prove they are unique
    if (remoteList.isNotEmpty) {
    }
    print("--------------------------------------------------");
    // ---------------------

    return _mergeAndDeduplicate(localList, remoteList);
  } catch (e) {
    return _loadFromAsset(localPath, languageCode, userId);
  }
}

  /// Merges two lists. 
  /// PREFERENCE: Local files keep precedence (for instant load/offline stability).
  /// New files from Firestore are added.
  List<LessonModel> _mergeAndDeduplicate(List<LessonModel> local, List<LessonModel> remote) {
    // 1. Create a map starting with local files
    final Map<String, LessonModel> lessonMap = {
      for (var item in local) item.id: item
    };

    // 2. Add remote files ONLY if they don't exist in local
    for (var item in remote) {
      if (!lessonMap.containsKey(item.id)) {
        lessonMap[item.id] = item;
      } else {
        // Optional: If you wanted Firestore to UPDATE local files, 
        // you would overwrite here: lessonMap[item.id] = item;
        // But for "Instant Load" and speed, we usually stick to the local version.
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
      
      // Use the shared mapper
      return data.map((item) => _mapJsonToLesson(item, languageCode, defaultUserId)).toList();
    } catch (e) {
      return [];
    }
  }

  // --- FIRESTORE LOADER ---
  Future<List<LessonModel>> _loadFromFirestore(
    String languageCode, 
    List<String> userIds // We pass a list of valid userIds (e.g. ['system', 'system_native'])
  ) async {
    try {
      // Query: lessons where language == 'es' AND userId IN ['system', 'system_native']
      // Note: Firestore 'whereIn' is limited to 10 items, which is fine here.
      final snapshot = await _firestore
          .collection('lessons')
          .where('language', isEqualTo: languageCode)
          .where('userId', whereIn: userIds)
          // .orderBy('createdAt', descending: true) // Optional: Get newest first
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        // Ensure ID from doc is used if not in data
        data['id'] = doc.id; 
        // We use the same userId from the doc, or fallback to the first allowed one
        return _mapJsonToLesson(data, languageCode, userIds.first);
      }).toList();
    } catch (e) {
      print("🔥 FIRESTORE ERROR (Language: $languageCode): $e");
      return []; // Return empty list on failure so app doesn't crash
    }
  }

  // --- SHARED MAPPER (DRY Principle) ---
  // This ensures your Local JSON and Firestore Documents are parsed exactly the same way.
  LessonModel _mapJsonToLesson(Map<String, dynamic> jsonItem, String languageCode, String defaultUserId) {
    final id = jsonItem['id']?.toString() ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}';

    // --- URL MAPPING FIX ---
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
      sentences: (jsonItem['sentences'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [],
      // Safely convert transcripts
      transcript: (jsonItem['transcript'] as List<dynamic>?)
              ?.map((e) => TranscriptLine.fromMap(e))
              .toList() ?? [],
      // Handle Firestore Timestamp vs JSON String
      createdAt: _parseDate(jsonItem['createdAt']),
      imageUrl: jsonItem['imageUrl'],
      type: jsonItem['type'] ?? 'text',
      difficulty: jsonItem['difficulty'] ?? 'intermediate',
      videoUrl: mediaUrl,
      isFavorite: jsonItem['isFavorite'] ?? false,
      progress: jsonItem['progress'] ?? 0,
    );
  }

  DateTime _parseDate(dynamic date) {
    if (date == null) return DateTime.now();
    if (date is Timestamp) return date.toDate(); // Firestore Timestamp
    if (date is String) return DateTime.tryParse(date) ?? DateTime.now(); // JSON String
    return DateTime.now();
  }
}