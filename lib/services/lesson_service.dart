import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/utils/logger.dart';

class LessonService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- 1. INITIAL FETCH (Original method kept and fixed) ---
  Future<List<LessonModel>> getLessons(
    String userId,
    String languageCode, {
    int limit = 20,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('lessons')
          .where('userId', isEqualTo: userId)
          .where('language', isEqualTo: languageCode)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => LessonModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print("Firestore Error (Initial Fetch): $e");
      return [];
    }
  }

  // --- 2. PAGINATION FETCH (Fixed for String-based dates from Python) ---
  Future<List<LessonModel>> getMoreLessons(
    String userId,
    String languageCode,
    LessonModel lastLesson, {
    int limit = 20,
  }) async {
    try {
      // Since Python saves 'createdAt' as a String, we must use the String
      // format in startAfter to match the Firestore index.
      final String lastDateString = lastLesson.createdAt
          .toUtc()
          .toIso8601String();

      final snapshot = await _firestore
          .collection('lessons')
          .where('userId', isEqualTo: userId)
          .where('language', isEqualTo: languageCode)
          .orderBy('createdAt', descending: true)
          .startAfter([lastDateString])
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => LessonModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print("Firestore Error (Pagination): $e");
      return [];
    }
  }

  // --- 3. UNIFIED FETCH (New: Loads User + System Content for 2024/2030 visibility) ---
  Future<List<LessonModel>> getMoreUnifiedLessons(
    List<String> userIds,
    String languageCode,
    LessonModel lastLesson, {
    int limit = 20,
  }) async {
    try {
      if (userIds.isEmpty) return [];

      final String lastDateString = lastLesson.createdAt
          .toUtc()
          .toIso8601String();

      final snapshot = await _firestore
          .collection('lessons')
          .where('language', isEqualTo: languageCode)
          .where('userId', whereIn: userIds)
          .orderBy('createdAt', descending: true)
          .startAfter([lastDateString])
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => LessonModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print("Firestore Error (Unified Pagination): $e");
      return [];
    }
  }

  // --- 4. CRUD OPERATIONS ---

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

  // --- 5. HELPER METHODS (Restored splitIntoSentences) ---

  List<String> splitIntoSentences(String text) {
    return text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  // --- 6. PAGINATION FOR GENRES ---
  Future<List<LessonModel>> fetchPagedGenreLessons(
    String languageCode,
    String genreKey,
    LessonModel? lastLesson, {
    int limit = 10,
  }) async {
    try {
      var query = _firestore
          .collection('lessons')
          .where('language', isEqualTo: languageCode)
          .where('genre', isEqualTo: genreKey)
          .where(
            'userId',
            whereIn: [
              'system',
              'system_native',
              'system_course',
              'system_audiobook',
            ],
          )
          .orderBy('createdAt', descending: true);

      if (lastLesson != null) {
        // Use ISO String cursor for Python-generated data
        final String lastDateString = lastLesson.createdAt
            .toUtc()
            .toIso8601String();
        query = query.startAfter([lastDateString]);
      }

      final snapshot = await query.limit(limit).get();

      return snapshot.docs.map((doc) {
        return LessonModel.fromMap(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      print("Genre Fetch Error ($genreKey): $e");
      return [];
    }
  }
}
