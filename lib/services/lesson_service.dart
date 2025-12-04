import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linguaflow/models/lesson_model.dart';

class LessonService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<LessonModel>> getLessons(String userId, String languageCode) async {
    print("DEBUG: FirestoreService -> Fetching for User: $userId, Lang: $languageCode");
    try {
      final snapshot = await _firestore
          .collection('lessons')
          .where('userId', isEqualTo: userId)
          .where('language', isEqualTo: languageCode)
          .orderBy('createdAt', descending: true)
          .get();

      print("DEBUG: FirestoreService -> Found ${snapshot.docs.length} docs");
      return snapshot.docs
          .map((doc) => LessonModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print("DEBUG: FirestoreService -> ❌ Error fetching lessons: $e");
      rethrow;
    }
  }

  Future<void> createLesson(LessonModel lesson) async {
    print("DEBUG: FirestoreService -> createLesson called for '${lesson.title}'");
    try {
      final ref = await _firestore.collection('lessons').add(lesson.toMap());
      print("DEBUG: FirestoreService -> ✅ Created successfully with ID: ${ref.id}");
    } catch (e) {
      print("DEBUG: FirestoreService -> ❌ Error creating lesson: $e");
      rethrow;
    }
  }

  Future<void> updateLesson(LessonModel lesson) async {
    print("DEBUG: FirestoreService -> updateLesson called for ID: ${lesson.id}");
    if (lesson.id.isEmpty) {
      print("DEBUG: FirestoreService -> ⚠️ Error: Tried to update with empty ID");
      return;
    }

    try {
      await _firestore
          .collection('lessons')
          .doc(lesson.id)
          .set(lesson.toMap(), SetOptions(merge: true));
      print("DEBUG: FirestoreService -> ✅ Updated successfully");
    } catch (e) {
      print("DEBUG: FirestoreService -> ❌ Error updating lesson: $e");
      rethrow;
    }
  }

  Future<void> deleteLesson(String lessonId) async {
    print("DEBUG: FirestoreService -> deleteLesson called for ID: $lessonId");
    try {
      await _firestore.collection('lessons').doc(lessonId).delete();
      print("DEBUG: FirestoreService -> ✅ Deleted successfully");
    } catch (e) {
      print("DEBUG: FirestoreService -> ❌ Error deleting: $e");
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
}