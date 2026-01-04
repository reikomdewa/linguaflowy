import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Required for the fix
import 'package:linguaflow/models/private_chat_models.dart';

class PrivateChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==============================================================================
  // 1. Get Inbox (FIXED: Handles Race Condition)
  // ==============================================================================
  Stream<List<PrivateConversation>> getInbox(String myUserId) {
    // We listen to Auth State. The Firestore query will ONLY run
    // when 'user' is not null.
    return _auth.authStateChanges().asyncExpand((user) {
      // 1. If Auth is not ready, return empty list (prevents Permission Denied)
      if (user == null) {
        return Stream.value([]);
      }

      // 2. Auth is ready, now we can safely query Firestore
      return _firestore
          .collection('private_chats')
          .where('participants', arrayContains: user.uid) // Use auth uid to be safe
          .orderBy('lastMessageTime', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => PrivateConversation.fromMap(doc.data(), doc.id))
            .toList();
      });
    });
  }

  // ==============================================================================
  // 2. Get Messages (FIXED: Handles Race Condition)
  // ==============================================================================
  Stream<List<PrivateMessage>> getMessages(String chatId) {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value([]);

      return _firestore
          .collection('private_chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => PrivateMessage.fromMap(doc.data(), doc.id))
            .toList();
      });
    });
  }

  // ==============================================================================
  // 3. Send Message
  // ==============================================================================
  Future<void> sendMessage(String chatId, String senderId, String text) async {
    if (text.trim().isEmpty) return;
    
    // Safety check: Ensure user is actually logged in before writing
    if (_auth.currentUser == null) return;

    final timestamp = DateTime.now();

    try {
      // A. Add message to subcollection
      await _firestore
          .collection('private_chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': senderId,
        'text': text.trim(),
        'createdAt': Timestamp.fromDate(timestamp),
        'isRead': false,
      });

      // B. Update the inbox preview
      // Note: In a real app, unreadCount usually needs to be specific per user 
      // (e.g. 'unreadCount_userId': increment), but keeping your logic simple here:
      await _firestore.collection('private_chats').doc(chatId).update({
        'lastMessage': text.trim(),
        'lastMessageTime': Timestamp.fromDate(timestamp),
        'lastSenderId': senderId,
        'isRead': false,
        'unreadCount': FieldValue.increment(1), 
      });
    } catch (e) {
      print("Error sending message: $e");
      rethrow;
    }
  }

  // ==============================================================================
  // 4. Mark Chat as Read
  // ==============================================================================
  Future<void> markChatAsRead(String chatId) async {
    if (_auth.currentUser == null) return;

    try {
      await _firestore.collection('private_chats').doc(chatId).update({
        'isRead': true,
        'unreadCount': 0,
      });
    } catch (e) {
      // Ignore errors if doc doesn't exist
      print("Error marking as read: $e");
    }
  }

  // ==============================================================================
  // 5. Start Chat
  // ==============================================================================
  Future<String> startChat({
    required String currentUserId,
    required String otherUserId,
    required String currentUserName,
    required String otherUserName,
    String? currentUserPhoto,
    String? otherUserPhoto,
  }) async {
    
    if (_auth.currentUser == null) throw Exception("User must be logged in");

    // A. Check if chat already exists
    // Note: This logic is fine for small scale. For large scale, store a combined key "id1_id2"
    final query = await _firestore
        .collection('private_chats')
        .where('participants', arrayContains: currentUserId)
        .get();

    for (var doc in query.docs) {
      final List<dynamic> participants = doc['participants'];
      if (participants.contains(otherUserId)) {
        return doc.id; // Found existing chat
      }
    }

    // B. Create new chat if not found
    final docRef = await _firestore.collection('private_chats').add({
      'participants': [currentUserId, otherUserId],
      'lastMessage': 'Started a conversation',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': currentUserId,
      'isRead': false,
      'unreadCount': 0,
      'participantData': {
        currentUserId: {
          'name': currentUserName,
          'photo': currentUserPhoto,
        },
        otherUserId: {
          'name': otherUserName,
          'photo': otherUserPhoto,
        },
      }
    });

    return docRef.id;
  }
}