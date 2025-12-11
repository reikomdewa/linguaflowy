import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linguaflow/models/lesson_model.dart';

class LessonService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<LessonModel>> getLessons(String userId, String languageCode) async {
    try {
      final snapshot = await _firestore
          .collection('lessons')
          .where('userId', isEqualTo: userId)
          .where('language', isEqualTo: languageCode)
          .orderBy('createdAt', descending: true)
          .get();

      // Note: Firestore lessons are never 'isLocal' by default
      return snapshot.docs
          .map((doc) => LessonModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      // Return empty list on error (offline) instead of crashing
      print("Firestore Error: $e");
      return [];
    }
  }

  Future<void> createLesson(LessonModel lesson) async {
    try {
      // Ensure we don't upload local paths to server
      if (lesson.isLocal) return; 
      
      await _firestore.collection('lessons').doc(lesson.id).set(lesson.toMap());
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateLesson(LessonModel lesson) async {
    if (lesson.id.isEmpty || lesson.isLocal) {
      return;
    }

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
}