import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/speak/speak_models.dart';

class SpeakService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  // inside SpeakService class
  Future<void> createTutorProfile(Tutor tutor) async {
    await _firestore
        .collection('tutors')
        .doc(tutor.id) // This will be the User UID
        .set(
          tutor.toMap(),
          SetOptions(merge: true),
        ); // Merge ensures we don't accidentally wipe metadata
  }

  Future<List<Tutor>> getTutors() async {
    final snapshot = await _firestore.collection('tutors').get();
    return snapshot.docs
        .map((doc) => Tutor.fromMap(doc.data(), doc.id))
        .toList();
  }

  // UPDATED: Use Top-Level Collection
  Future<void> createRoom(ChatRoom room) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    try {
      // Logic change: Save directly to 'rooms' collection
      await _firestore.collection('rooms').doc(room.id).set(room.toMap());
    } catch (e) {
      throw Exception("Failed to create room: $e");
    }
  }

  // UPDATED: Fetch Public Feed (with optional filters)
  // Add these to your SpeakService class
  Future<void> deleteTutorProfile(String tutorId) async {
    await _firestore.collection('tutors').doc(tutorId).delete();
  }

  Future<void> deleteRoom(String roomId) async {
    await _firestore.collection('rooms').doc(roomId).delete();
  }

  Future<List<ChatRoom>> getPublicRooms() async {
    // This is what populates your "All" or "Rooms" tab
    final snapshot = await _firestore
        .collection('rooms')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => ChatRoom.fromMap(doc.data(), doc.id))
        .toList();
  }

  // Helper: If you still need to find "My Rooms", you use a simple 'where' query
  Future<List<ChatRoom>> getMyRooms() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _firestore
        .collection('rooms')
        .where(
          'hostId',
          isEqualTo: user.uid,
        ) // Query by the field inside the doc
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => ChatRoom.fromMap(doc.data(), doc.id))
        .toList();
  }
  // ... inside SpeakService class ...

  /// Mock function to get a token.
  /// IN PRODUCTION: Fetch this from your backend API (Node/Python/Go)
  Future<String> getLiveKitToken(String roomId, String username) async {
    try {
      // 1. Call the Cloud Function we just deployed
      final result = await _functions
          .httpsCallable('generateLiveKitToken')
          .call({'roomId': roomId, 'username': username});

      // 2. Extract token from response
      final String token = result.data['token'];
      return token;
    } catch (e) {
      print("Error generating token: $e");
      throw Exception("Failed to generate LiveKit token");
    }
  }
}
