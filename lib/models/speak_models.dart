import 'package:equatable/equatable.dart';

// --- Free4Talk Style Room ---
class ChatRoom extends Equatable {
  final String id;
  final String hostId; // New: To link back to the user
  final String title;
  final String language;
  final String level;
  final int memberCount;
  final int maxMembers;
  final bool isPaid;
  final String? hostName;
  final String? hostAvatarUrl; // Optional: For the UI

  const ChatRoom({
    required this.id,
    required this.hostId,
    required this.title,
    required this.language,
    required this.level,
    required this.memberCount,
    required this.maxMembers,
    this.isPaid = false,
    this.hostName,
    this.hostAvatarUrl,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hostId': hostId,
      'title': title,
      'language': language,
      'level': level,
      'memberCount': memberCount,
      'maxMembers': maxMembers,
      'isPaid': isPaid,
      'hostName': hostName,
      'hostAvatarUrl': hostAvatarUrl,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  // Create from Firestore
  factory ChatRoom.fromMap(Map<String, dynamic> map, String id) {
    return ChatRoom(
      id: id,
      hostId: map['hostId'] ?? '',
      title: map['title'] ?? '',
      language: map['language'] ?? 'English',
      level: map['level'] ?? 'Any',
      memberCount: map['memberCount']?.toInt() ?? 0,
      maxMembers: map['maxMembers']?.toInt() ?? 5,
      isPaid: map['isPaid'] ?? false,
      hostName: map['hostName'],
      hostAvatarUrl: map['hostAvatarUrl'],
    );
  }

  @override
  List<Object?> get props => [id, title, memberCount, hostId];
}

// ... Tutor model remains the same ...
class Tutor extends Equatable {
  // ... existing code ...
  final String id;
  final String name;
  final String language;
  final double rating;
  final int reviews;
  final double pricePerHour;
  final String imageUrl;

  const Tutor({
    required this.id,
    required this.name,
    required this.language,
    required this.rating,
    required this.reviews,
    required this.pricePerHour,
    required this.imageUrl,
  });

  @override
  List<Object?> get props => [id, name, rating];
}