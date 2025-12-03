import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linguaflow/models/vocabulary_item.dart';

class VocabularyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper to ensure IDs match the Reader logic (e.g. "C'est" -> "cest")
  String _generateDocId(String word) {
    return word.toLowerCase().trim().replaceAll(RegExp(r'[^\w\s]'), '');
  }

  Future<List<VocabularyItem>> getVocabulary(String userId) async {
    try {
      // 1. Get reference to the specific user's subcollection
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('vocabulary')
          .get(); // Removed orderBy temporarily to prevent index errors during dev

      // 2. Map safely using the fixed Model
      return snapshot.docs.map((doc) {
        return VocabularyItem.fromMap(doc.data(), doc.id);
      }).toList();
      
    } catch (e) {
      print("Error in VocabularyService.getVocabulary: $e");
      return [];
    }
  }

  Future<void> addVocabulary(VocabularyItem item) async {
    final String docId = _generateDocId(item.word);
    final String actualId = docId.isNotEmpty ? docId : item.id;

    await _firestore
        .collection('users')
        .doc(item.userId)
        .collection('vocabulary')
        .doc(actualId)
        .set(item.toMap(), SetOptions(merge: true));
  }

  Future<void> updateVocabulary(VocabularyItem item) async {
    // We use set(merge: true) to be safe
    final String docId = _generateDocId(item.word);
    final String actualId = docId.isNotEmpty ? docId : item.id;

    await _firestore
        .collection('users')
        .doc(item.userId)
        .collection('vocabulary')
        .doc(actualId)
        .set(item.toMap(), SetOptions(merge: true));
  }
}