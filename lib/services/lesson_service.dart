import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linguaflow/models/lesson_model.dart';

class LessonService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Added languageCode parameter
  Future<List<LessonModel>> getLessons(
    String userId,
    String languageCode,
  ) async {
    final snapshot = await _firestore
        .collection('lessons')
        .where('userId', isEqualTo: userId)
        .where('language', isEqualTo: languageCode) // Filter by global language
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => LessonModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> createLesson(LessonModel lesson) async {
    await _firestore.collection('lessons').add(lesson.toMap());
  }

 // services/lesson_service.dart

Future<void> updateLesson(LessonModel lesson) async {
  if (lesson.id.isEmpty) return;

  // KEY CHANGE: Use set() with merge: true
  // If the doc exists, it updates fields.
  // If it doesn't exist (it was a local JSON file), it creates it in the cloud.
  await _firestore
      .collection('lessons')
      .doc(lesson.id)
      .set(lesson.toMap(), SetOptions(merge: true));
}

  Future<void> deleteLesson(String lessonId) async {
    await _firestore.collection('lessons').doc(lessonId).delete();
  }

  Future<LessonModel> getLesson(String lessonId) async {
    final doc = await _firestore.collection('lessons').doc(lessonId).get();
    if (!doc.exists || doc.data() == null) {
      throw Exception("Lesson not found");
    }
    return LessonModel.fromMap(doc.data()!, doc.id);
  }

  List<String> splitIntoSentences(String text) {
    return text
        .split(
          RegExp(r'(?<=[.!?])\s+'),
        ) // Improved regex to keep punctuation attached to the previous sentence if possible, or split naturally
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
