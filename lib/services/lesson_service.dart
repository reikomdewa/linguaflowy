import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/utils/logger.dart';

class LessonService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- 1. INITIAL FETCH (With Crash Protection) ---
  Future<List<LessonModel>> getLessons(
    String userId,
    String languageCode, {
    int limit = 20, // <--- ADDED: Defaults to 20 to prevent OOM Crash
  }) async {
    try {
      final snapshot = await _firestore
          .collection('lessons')
          .where('userId', isEqualTo: userId)
          .where('language', isEqualTo: languageCode)
          .orderBy('createdAt', descending: true)
          .limit(limit) // <--- CRITICAL: Limits download size
          .get();

      return snapshot.docs
          .map((doc) => LessonModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      printLog("Firestore Error (Initial Fetch): $e");
      return [];
    }
  }

  // --- 2. PAGINATION FETCH (Load More) ---
  Future<List<LessonModel>> getMoreLessons(
    String userId,
    String languageCode,
    LessonModel lastLesson, { // The last lesson currently on screen
    int limit = 20,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('lessons')
          .where('userId', isEqualTo: userId)
          .where('language', isEqualTo: languageCode)
          .orderBy('createdAt', descending: true)
          // Tell Firestore to start AFTER the date of the last lesson we have
          .startAfter([Timestamp.fromDate(lastLesson.createdAt)])
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => LessonModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      printLog("Firestore Error (Pagination): $e");
      return [];
    }
  }

  // --- CRUD OPERATIONS (Unchanged) ---

  Future<void> createLesson(LessonModel lesson) async {
    try {
      if (lesson.isLocal) return;
      await _firestore.collection('lessons').doc(lesson.id).set(lesson.toMap());
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateLesson(LessonModel lesson) async {
    if (lesson.id.isEmpty || lesson.isLocal) return;

    try {
      await _firestore
          .collection('lessons')
          .doc(lesson.id)
          .set(lesson.toMap(), SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteLesson(String lessonId) async {
    try {
      await _firestore.collection('lessons').doc(lessonId).delete();
    } catch (e) {
      rethrow;
    }
  }

  List<String> splitIntoSentences(String text) {
    return text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  // --- PAGINATION FOR GENRES ---
  Future<List<LessonModel>> fetchPagedGenreLessons(
    String languageCode,
    String genreKey,
    LessonModel? lastLesson, {
    int limit = 10,
  }) async {
    try {
      // Look for videos in this language with the specific genre
      var query = _firestore
          .collection('lessons')
          .where('language', isEqualTo: languageCode)
          .where('genre', isEqualTo: genreKey) // Strict genre match
          // We generally only want system/native videos in feeds, not user created ones
          .where('userId', whereIn: ['system', 'system_native'])
          .orderBy('createdAt', descending: true);

      if (lastLesson != null) {
        query = query.startAfter([Timestamp.fromDate(lastLesson.createdAt)]);
      }

      final snapshot = await query.limit(limit).get();

      return snapshot.docs.map((doc) {
        return LessonModel.fromMap(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      printLog("Genre Fetch Error ($genreKey): $e");
      // You will likely need to create an Index link from the console for this to work
      return [];
    }
  }
}
