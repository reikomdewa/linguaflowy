import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:linguaflow/models/speak/room_member.dart';
import '../../models/speak/speak_models.dart';

class SpeakService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<void> createTutorProfile(Tutor tutor) async {
    // Ensure we await the firestore call
    await _firestore
        .collection('tutors')
        .doc(tutor.id)
        .set(tutor.toMap(), SetOptions(merge: true));
  }

  Future<List<Tutor>> getTutors() async {
    final snapshot = await _firestore.collection('tutors').get();
    return snapshot.docs
        .map((doc) => Tutor.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> createRoom(ChatRoom room) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");
    
    // Explicitly await the set operation
    await _firestore.collection('rooms').doc(room.id).set(room.toMap());
  }

  // NEW: Helper to persist members when someone joins
  Future<void> updateRoomMembers(String roomId, List<RoomMember> members, int count) async {
    await _firestore.collection('rooms').doc(roomId).update({
      'members': members.map((m) => m.toMap()).toList(),
      'memberCount': count,
    });
  }

  Future<void> deleteTutorProfile(String tutorId) async => 
      await _firestore.collection('tutors').doc(tutorId).delete();

  Future<void> deleteRoom(String roomId) async => 
      await _firestore.collection('rooms').doc(roomId).delete();

  Future<List<ChatRoom>> getPublicRooms() async {
    final snapshot = await _firestore
        .collection('rooms')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => ChatRoom.fromMap(doc.data(), doc.id)).toList();
  }

  Future<String> getLiveKitToken(String roomId, String username) async {
    try {
      final result = await _functions
          .httpsCallable('generateLiveKitToken')
          .call({'roomId': roomId, 'username': username});
      return result.data['token'];
    } catch (e) {
      throw Exception("Failed to generate token: $e");
    }
  }
}