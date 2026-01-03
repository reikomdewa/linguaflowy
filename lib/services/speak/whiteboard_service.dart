import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linguaflow/blocs/speak/whiteboard_models.dart';

class WhiteboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add generic object (Text or Stroke)
  Future<void> addObject(String roomId, String userId, WhiteboardObject object) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('whiteboards')
        .doc(userId)
        .collection('objects') // Renamed collection from 'strokes' to 'objects'
        .add(object.toMap());
  }

  // Clear specific user's whiteboard
  Future<void> clearBoard(String roomId, String userId) async {
    final ref = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('whiteboards')
        .doc(userId)
        .collection('objects');

    final batch = _firestore.batch();
    var snapshots = await ref.get();
    for (var doc in snapshots.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // Stream objects
  Stream<List<WhiteboardObject>> streamObjects(String roomId, String targetUserId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('whiteboards')
        .doc(targetUserId)
        .collection('objects')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => WhiteboardObject.fromMap(doc.data(), doc.id))
          .toList();
    });
  }
}