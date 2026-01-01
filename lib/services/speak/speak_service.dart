import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http; // Add http to pubspec.yaml
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:linguaflow/models/speak/room_member.dart';
import '../../models/speak/speak_models.dart';

class SpeakService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- TUTOR LOGIC ---

  Future<void> createTutorProfile(Tutor tutor) async {
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

  Future<void> deleteTutorProfile(String tutorId) async =>
      await _firestore.collection('tutors').doc(tutorId).delete();

  // --- ROOM LOGIC ---

  Future<void> createRoom(ChatRoom room) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    // Create room in Top-Level 'rooms' collection for public access
    await _firestore.collection('rooms').doc(room.id).set(room.toMap());
  }

  Future<void> updateRoomMembers(
    String roomId,
    List<RoomMember> members,
    int count,
  ) async {
    await _firestore.collection('rooms').doc(roomId).update({
      'members': members.map((m) => m.toMap()).toList(),
      'memberCount': count,
    });
  }

  Future<void> deleteRoom(String roomId) async =>
      await _firestore.collection('rooms').doc(roomId).delete();

  Future<List<ChatRoom>> getPublicRooms() async {
    final snapshot = await _firestore
        .collection('rooms')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => ChatRoom.fromMap(doc.data(), doc.id))
        .toList();
  }

  // --- LIVEKIT TOKEN LOGIC (Via Netlify) ---

  Future<String> getLiveKitToken(String roomId, String username) async {
    // 1. Separate Authority and Path for cleaner URI construction
    const String authority = "linguaflowy.netlify.app";
    const String path = "/.netlify/functions/getToken";

    try {
      // 2. Use Uri.https to automatically encode query parameters
      // This fixes issues if username/room has spaces or special chars
      final uri = Uri.https(authority, path, {
        'roomName': roomId,
        'username': username,
      });

      // 3. Add a Timeout to prevent infinite loading
      final response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException(
                "Connection timed out. Please check your internet.",
              );
            },
          );

      if (response.statusCode == 200) {
        // 4. Safe JSON Decoding
        final data = jsonDecode(response.body);

        // 5. Validate the Data
        if (data is Map && data.containsKey('token') && data['token'] != null) {
          return data['token'].toString();
        } else {
          throw Exception("Invalid response: Token missing from server");
        }
      } else {
        throw Exception(
          "Server Error (${response.statusCode}): ${response.body}",
        );
      }
    } on SocketException {
      throw Exception("No Internet Connection");
    } on FormatException {
      throw Exception("Bad Response Format: Server returned invalid JSON");
    } catch (e) {
      // Re-throw concise errors to the UI
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // 1. TOGGLE FAVORITE
  Future<void> toggleFavorite(String tutorId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userRef = _firestore.collection('users').doc(user.uid);
    final doc = await userRef.get();

    if (doc.exists) {
      final List<dynamic> favorites = doc.data()?['favoriteTutors'] ?? [];

      if (favorites.contains(tutorId)) {
        // Remove
        await userRef.update({
          'favoriteTutors': FieldValue.arrayRemove([tutorId]),
        });
      } else {
        // Add
        await userRef.update({
          'favoriteTutors': FieldValue.arrayUnion([tutorId]),
        });
      }
    }
  }

  // 2. REPORT TUTOR
  Future<void> reportTutor(String tutorId, String reason) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('reports').add({
      'targetId': tutorId,
      'type': 'tutor_profile',
      'reporterId': user.uid,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending', // for admin review
    });
  }

  // ... existing code ...

  /// Listen to live rooms in real-time
  Stream<List<ChatRoom>> getPublicRoomsStream() {
    return _firestore
        .collection('rooms')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ChatRoom.fromMap(doc.data(), doc.id))
              .toList();
        });
  }
}
