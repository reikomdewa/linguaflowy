import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linguaflow/screens/quiz/widgets/quiz_level.dart';
import 'package:linguaflow/utils/logger.dart';

class QuizPathRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fetches the Duolingo-style path for a specific language
  Future<List<QuizLevel>> getPathForLanguage(String languageCode) async {
    try {
      final snapshot = await _db
          .collection('quiz_levels')
          .where('language', isEqualTo: languageCode)
          .orderBy('unitIndex', descending: false) // Order: Unit 1 -> Unit 2...
          .get();

      return snapshot.docs.map((doc) => QuizLevel.fromMap(doc.data())).toList();
    } catch (e) {
      printLog("Error fetching quiz path: $e");
      return [];
    }
  }
}
