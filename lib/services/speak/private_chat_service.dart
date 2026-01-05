import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:linguaflow/models/private_chat_models.dart';

class PrivateChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==============================================================================
  // HELPER: Generate Consistent Chat ID
  // ==============================================================================
  // Sorts IDs alphabetically so "UserA" + "UserB" always = "UserA_UserB"
  String _getChatId(String id1, String id2) {
    List<String> ids = [id1, id2];
    ids.sort(); 
    return ids.join('_');
  }

  // ==============================================================================
  // 1. Get Inbox
  // ==============================================================================
  Stream<List<PrivateConversation>> getInbox(String myUserId) {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value([]);

      return _firestore
          .collection('private_chats')
          .where('participants', arrayContains: user.uid) 
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
  // 2. Get Messages
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
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
    String? senderName,
    String? senderPhoto,
    String? otherName,
    String? otherPhoto,
  }) async {
    if (text.trim().isEmpty) return;
    if (_auth.currentUser == null) return;

    final timestamp = DateTime.now();
    
    // Ensure we have at least a fallback name
    final safeSenderName = (senderName == null || senderName.isEmpty) ? 'User' : senderName;
    final safeOtherName = (otherName == null || otherName.isEmpty) ? 'User' : otherName;

    // Extract participants from ID (e.g. "userA_userB")
    final participants = chatId.split('_');
    final otherId = participants.firstWhere((id) => id != senderId, orElse: () => '');

    try {
      // A. Write to Messages Subcollection
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

      // B. Prepare Parent Document Data
      // We explicitly build the participantData map
      Map<String, dynamic> participantData = {
        senderId: {
          'name': safeSenderName, 
          'photo': senderPhoto
        },
      };

      // Only add the other user's data if we successfully identified their ID
      if (otherId.isNotEmpty) {
        participantData[otherId] = {
          'name': safeOtherName, 
          'photo': otherPhoto
        };
      }

      // C. Update Parent Document (Inbox Preview)
      await _firestore.collection('private_chats').doc(chatId).set({
        'participants': participants,
        'lastMessage': text.trim(),
        'lastMessageTime': Timestamp.fromDate(timestamp),
        'lastSenderId': senderId,
        'isRead': false,
        'unreadCount': FieldValue.increment(1),
        // This ensures the names are saved to the document
        'participantData': participantData, 
      }, SetOptions(merge: true));
      
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
      // We only reset the count if we are NOT the last sender
      // (Requires fetching the doc to check lastSenderId, but for simple UI we just reset)
      await _firestore.collection('private_chats').doc(chatId).update({
        'isRead': true,
        'unreadCount': 0,
      });
    } catch (e) {
      print("Error marking as read: $e");
    }
  }

  // ==============================================================================
  // 5. Start Chat (FIXED: Deterministic ID)
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

    // A. Generate ID: "user1_user2"
    final chatId = _getChatId(currentUserId, otherUserId);
    final chatDoc = _firestore.collection('private_chats').doc(chatId);

    // B. Check if it exists
    final snapshot = await chatDoc.get();

    if (snapshot.exists) {
      return chatId; // Chat already exists, return ID
    }

    // C. Create it if it doesn't exist
    await chatDoc.set({
      'participants': [currentUserId, otherUserId],
      'lastMessage': 'Started conversation', // Initial text
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': currentUserId,
      'isRead': true,
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

    return chatId;
  }
}