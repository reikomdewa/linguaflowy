import 'package:cloud_firestore/cloud_firestore.dart';

class PrivateMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final bool isRead;

  PrivateMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
    };
  }

  factory PrivateMessage.fromMap(Map<String, dynamic> map, String id) {
    return PrivateMessage(
      id: id,
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      isRead: map['isRead'] ?? false,
    );
  }
}

class PrivateConversation {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime lastMessageTime;
  // We store user names/photos here so we don't have to fetch them 
  // every time we load the inbox list (Denormalization).
  final Map<String, dynamic> participantData; 

  PrivateConversation({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.participantData,
  });

  factory PrivateConversation.fromMap(Map<String, dynamic> map, String id) {
    return PrivateConversation(
      id: id,
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime: map['lastMessageTime'] != null 
          ? (map['lastMessageTime'] as Timestamp).toDate() 
          : DateTime.now(),
      participantData: Map<String, dynamic>.from(map['participantData'] ?? {}),
    );
  }
}