import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:linguaflow/models/user_model.dart';
import 'package:linguaflow/utils/logger.dart'; // Assuming you have this

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // =========================================================
  // 1. PROFILE MANAGEMENT
  // =========================================================

  /// Update the bio or other profile details
  Future<void> updateProfile({String? bio, String? displayName, String? photoUrl}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final Map<String, dynamic> updates = {};
    if (bio != null) updates['bio'] = bio;
    if (displayName != null) updates['displayName'] = displayName;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;

    if (updates.isNotEmpty) {
      await _firestore.collection('users').doc(uid).update(updates);
    }
  }

  /// Get ANY user's profile (not just the logged in one)
  /// Useful when clicking on a face in the Room Grid
  Future<UserModel?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
    } catch (e) {
      printLog("Error fetching user profile: $e");
    }
    return null;
  }

  // =========================================================
  // 2. SOCIAL GRAPH (Following / Followers)
  // =========================================================

  /// Follow a user (Tutor or Peer)
  /// Uses a BATCH write to ensure both documents update, or neither does.
  Future<void> followUser(String targetUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception("Not logged in");
    if (currentUserId == targetUserId) throw Exception("Cannot follow yourself");

    final batch = _firestore.batch();

    // 1. Add target to MY 'following' list
    final myDocRef = _firestore.collection('users').doc(currentUserId);
    batch.update(myDocRef, {
      'following': FieldValue.arrayUnion([targetUserId])
    });

    // 2. Add ME to target's 'followers' list
    final targetDocRef = _firestore.collection('users').doc(targetUserId);
    batch.update(targetDocRef, {
      'followers': FieldValue.arrayUnion([currentUserId])
    });

    await batch.commit();
  }

  /// Unfollow a user
  Future<void> unfollowUser(String targetUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    final batch = _firestore.batch();

    // 1. Remove target from MY 'following' list
    final myDocRef = _firestore.collection('users').doc(currentUserId);
    batch.update(myDocRef, {
      'following': FieldValue.arrayRemove([targetUserId])
    });

    // 2. Remove ME from target's 'followers' list
    final targetDocRef = _firestore.collection('users').doc(targetUserId);
    batch.update(targetDocRef, {
      'followers': FieldValue.arrayRemove([currentUserId])
    });

    await batch.commit();
  }

  // =========================================================
  // 3. FRIENDS (Bidirectional)
  // =========================================================
  // Logic: Usually "Friend" means both follow each other, or it's a specific request.
  // For simplicity, let's assume if I add you as a friend, it's a direct add (like adding contacts).
  
  Future<void> addFriend(String targetUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    await _firestore.collection('users').doc(currentUserId).update({
      'friends': FieldValue.arrayUnion([targetUserId])
    });
  }

  Future<void> removeFriend(String targetUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    await _firestore.collection('users').doc(currentUserId).update({
      'friends': FieldValue.arrayRemove([targetUserId])
    });
  }

  // =========================================================
  // 4. BLOCKING / SAFETY
  // =========================================================

  Future<void> blockUser(String targetUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    final batch = _firestore.batch();
    final myDocRef = _firestore.collection('users').doc(currentUserId);

    // 1. Add to blocked list
    batch.update(myDocRef, {
      'blockedUsers': FieldValue.arrayUnion([targetUserId])
    });

    // 2. Force Unfollow (Safety measure)
    batch.update(myDocRef, {
      'following': FieldValue.arrayRemove([targetUserId]),
      'friends': FieldValue.arrayRemove([targetUserId]),
    });

    await batch.commit();
  }

  Future<void> unblockUser(String targetUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    await _firestore.collection('users').doc(currentUserId).update({
      'blockedUsers': FieldValue.arrayRemove([targetUserId])
    });
  }
}