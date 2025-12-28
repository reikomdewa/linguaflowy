import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linguaflow/models/community_models.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/user_model.dart';
import 'package:uuid/uuid.dart';

class CommunityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- 1. SHARED LESSONS FEED ---
// Update this method in lib/services/community_service.dart
Stream<List<LessonModel>> getPublicLessons(String language) {
  // Ensure we match the broad language code (e.g. 'fr' instead of 'fr-FR')
  final String cleanLang = language.split('-')[0].split('_')[0].toLowerCase();

  return _firestore
      .collection('lessons')
      .where('isPublic', isEqualTo: true)
      .where('language', isEqualTo: cleanLang) // Use clean code
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => LessonModel.fromMap(doc.data(), doc.id))
          .toList());
}

  // --- 2. FORUM FEED ---
  Stream<List<ForumPost>> getForumPosts(String language) {
    return _firestore
        .collection('forum_posts')
        .where('language', isEqualTo: language)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ForumPost.fromMap(doc.data(), doc.id))
            .toList());
  }

  // --- 3. ACTIONS (Like, Save, Post) ---

  Future<void> createPost(ForumPost post) async {
    await _firestore.collection('forum_posts').doc(post.id).set(post.toMap());
  }

 // --- 1. TOGGLE LIKE (Fixed) ---
  Future<void> toggleLike(String collection, String docId, String userId) async {
    final docRef = _firestore.collection(collection).doc(docId);
    final likeRef = docRef.collection('likes').doc(userId);

    try {
      final likeSnap = await likeRef.get();

      if (likeSnap.exists) {
        // Unlike
        await likeRef.delete();
        await docRef.update({'likes': FieldValue.increment(-1)});
      } else {
        // Like
        await likeRef.set({'likedAt': FieldValue.serverTimestamp()});
        await docRef.update({'likes': FieldValue.increment(1)});
      }
    } catch (e) {
      // Handle error silently or log
    }
  }

  // --- 2. CHECK IF LIKED (New) ---
  Future<bool> hasUserLiked(String collection, String docId, String userId) async {
    final doc = await _firestore
        .collection(collection)
        .doc(docId)
        .collection('likes')
        .doc(userId)
        .get();
    return doc.exists;
  }

  // --- 3. INCREMENT VIEWS (New) ---
  Future<void> incrementLessonViews(String lessonId) async {
    await _firestore.collection('lessons').doc(lessonId).update({
      'views': FieldValue.increment(1),
    });
  }
// Add this to your CommunityService class
  Future<void> deletePost(String postId) async {
    try {
      await _firestore.collection('forum_posts').doc(postId).delete();
    } catch (e) {
      // Handle error (e.g. log it)
      throw Exception("Failed to delete post");
    }
  }
  // ... existing code ...

  // --- COMMENTS ---
  
  // 1. Fetch Comments
  Stream<List<Map<String, dynamic>>> getComments(String postId) {
    return _firestore
        .collection('forum_posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false) // Oldest first (like chat)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  // 2. Add Comment
  Future<void> addComment(String postId, String text, UserModel user) async {
    final commentData = {
      'authorId': user.id,
      'authorName': user.displayName.isEmpty ? 'User' : user.displayName,
      'authorPhoto': user.photoUrl,
      'content': text,
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Add to subcollection
    await _firestore
        .collection('forum_posts')
        .doc(postId)
        .collection('comments')
        .add(commentData);

    // Increment comment count on the main post
    await _firestore
        .collection('forum_posts')
        .doc(postId)
        .update({'commentCount': FieldValue.increment(1)});
  }
  // --- 4. REPORTING SYSTEM ---
  Future<void> reportContent({
    required String reporterId,
    required String contentId,
    required String contentType, // 'lesson', 'post', 'user'
    required String reason,
    required String description,
  }) async {
    await _firestore.collection('reports').add({
      'reporterId': reporterId,
      'contentId': contentId,
      'contentType': contentType,
      'reason': reason,
      'description': description,
      'status': 'pending', // pending, reviewed, actioned
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // --- 5. SAVE COMMUNITY LESSON TO LIBRARY ---
  Future<void> saveLessonToLibrary(LessonModel lesson, String currentUserId) async {
    // We create a COPY for the user, but keep lineage
    final newId = const Uuid().v4();
    
    final myCopy = lesson.copyWith(
      id: newId,
      userId: currentUserId,
      originalAuthorId: lesson.originalAuthorId ?? lesson.userId, // Maintain lineage
      isPublic: false, // Private copy
      isFavorite: false,
      createdAt: DateTime.now(),
      progress: 0,
      // Keep isLocal false because it's still cloud content, just copied
      isLocal: false, 
    );

    await _firestore.collection('lessons').doc(newId).set(myCopy.toMap());
  }

  // --- SEARCH LESSONS ---
  Stream<List<LessonModel>> searchPublicLessons(String query, String language) {
    final String cleanLang = language.split('-')[0].split('_')[0].toLowerCase();
    
    // Note: This requires a specific Composite Index in Firebase.
    // Check your debug console for the link to create it if it fails.
    return _firestore
        .collection('lessons')
        .where('isPublic', isEqualTo: true)
        .where('language', isEqualTo: cleanLang)
        .where('title', isGreaterThanOrEqualTo: query)
        .where('title', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LessonModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // --- SEARCH FORUM ---
  Stream<List<ForumPost>> searchForumPosts(String query, String language) {
    final String cleanLang = language.split('-')[0].split('_')[0].toLowerCase();

    return _firestore
        .collection('forum_posts')
        .where('language', isEqualTo: cleanLang)
        // We search by 'content'. Ideally, you'd search a 'keywords' array or 'title' if you added one.
        .where('content', isGreaterThanOrEqualTo: query)
        .where('content', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ForumPost.fromMap(doc.data(), doc.id))
            .toList());
  }
}