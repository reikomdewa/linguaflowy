import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linguaflow/blocs/speak/whiteboard_models.dart';

class WhiteboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add object
  Future<void> addObject(
    String roomId,
    String userId,
    WhiteboardObject object,
  ) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('whiteboards')
        .doc(userId)
        .collection('objects')
        .doc(object.id) // Use the object ID as the doc ID
        .set(object.toMap());
  }

  // --- NEW: Update Position (Required for Dragging) ---
  Future<void> updateObjectPosition(
    String roomId,
    String userId,
    String objectId,
    double x,
    double y,
  ) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('whiteboards')
        .doc(userId)
        .collection('objects')
        .doc(objectId)
        .update({'posX': x, 'posY': y});
  }

  // Delete Object (For Eraser/Undo)
  Future<void> deleteObject(
    String roomId,
    String userId,
    String objectId,
  ) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('whiteboards')
        .doc(userId)
        .collection('objects')
        .doc(objectId)
        .delete();
  }

  // Clear Board
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

  // Stream
  Stream<List<WhiteboardObject>> streamObjects(
    String roomId,
    String targetUserId,
  ) {
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
