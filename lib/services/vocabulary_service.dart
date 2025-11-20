// File: lib/services/vocabulary_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linguaflow/models/vocabulary_item.dart';

class VocabularyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<VocabularyItem>> getVocabulary(String userId) async {
    final snapshot = await _firestore
        .collection('vocabulary')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => VocabularyItem.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> addVocabulary(VocabularyItem item) async {
    await _firestore.collection('vocabulary').add(item.toMap());
  }

  Future<void> updateVocabulary(VocabularyItem item) async {
    await _firestore.collection('vocabulary').doc(item.id).update(item.toMap());
  }

  Future<VocabularyItem?> findWord(String userId, String word, String language) async {
    final snapshot = await _firestore
        .collection('vocabulary')
        .where('userId', isEqualTo: userId)
        .where('word', isEqualTo: word.toLowerCase())
        .where('language', isEqualTo: language)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return VocabularyItem.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
  }
}
