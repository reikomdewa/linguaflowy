import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linguaflow/models/private_chat_models.dart';

class PrivateChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. Get Inbox (Chats where I am a participant)
  Stream<List<PrivateConversation>> getInbox(String myUserId) {
    return _firestore
        .collection('private_chats')
        .where('participants', arrayContains: myUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PrivateConversation.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // 2. Get Messages for a specific chat
  Stream<List<PrivateMessage>> getMessages(String chatId) {
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
  }

  // 3. Send Message (FIXED FOR ACCURACY)
  Future<void> sendMessage(String chatId, String senderId, String text) async {
    if (text.trim().isEmpty) return;
    
    final timestamp = DateTime.now();

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

    // B. Update the inbox preview (CRITICAL FOR BADGES)
    await _firestore.collection('private_chats').doc(chatId).update({
      'lastMessage': text.trim(),
      'lastMessageTime': Timestamp.fromDate(timestamp),
      'lastSenderId': senderId, // <--- Key for knowing who sent it
      'isRead': false,   
       'unreadCount': FieldValue.increment(1),       // <--- Mark as unread for the recipient
    });
  }

  // 4. Mark Chat as Read (NEW - Call this when opening the screen)
  Future<void> markChatAsRead(String chatId) async {
    try {
      await _firestore.collection('private_chats').doc(chatId).update({
        'isRead': true,
        'unreadCount': 0, 
      });
    } catch (e) {
      // Ignore errors if doc doesn't exist or network fails
    }
  }

  // 5. Start Chat (Find existing or Create new)
  Future<String> startChat({
    required String currentUserId,
    required String otherUserId,
    required String currentUserName,
    required String otherUserName,
    String? currentUserPhoto,
    String? otherUserPhoto,
  }) async {
    // A. Check if chat already exists
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
      'lastSenderId': currentUserId, // Initialize sender
      'isRead': false,
       'unreadCount': 0, // Initialize as unread
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