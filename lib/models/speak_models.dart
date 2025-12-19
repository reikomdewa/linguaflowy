import 'package:equatable/equatable.dart';
import 'package:linguaflow/models/room_member.dart';

// --- Free4Talk Style Room ---
class ChatRoom extends Equatable {
  final String id;
  final String hostId;
  final String title;
  final String language;
  final String level;
  final int memberCount; // Total count (even if list is capped)
  final int maxMembers;
  final bool isPaid;
  final bool isPrivate; // For future: rooms via invite link
  final String? hostName;
  final String? hostAvatarUrl;
  final List<RoomMember> members; // The specific members for UI
  final DateTime createdAt;
  final String? liveKitRoomId; // Link to the media server session

  const ChatRoom({
    required this.id,
    required this.hostId,
    required this.title,
    required this.language,
    required this.level,
    required this.memberCount,
    required this.maxMembers,
    required this.members,
    required this.createdAt,
    this.isPaid = false,
    this.isPrivate = false,
    this.hostName,
    this.hostAvatarUrl,
    this.liveKitRoomId,
  });

  // Helper logic to get avatars for the UI row
  List<RoomMember> get displayMembers {
    // Return first 10 members to keep UI clean
    return members.take(10).toList();
  }

  int get othersCount {
    return memberCount > 10 ? memberCount - 10 : 0;
  }

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
      'isPrivate': isPrivate,
      'hostName': hostName,
      'hostAvatarUrl': hostAvatarUrl,
      'liveKitRoomId': liveKitRoomId ?? id,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'members': members.map((m) => m.toMap()).toList(),
    };
  }

  factory ChatRoom.fromMap(Map<String, dynamic> map, String id) {
    // Robust parsing of members list
    var memberList = <RoomMember>[];
    if (map['members'] != null) {
      memberList = List<RoomMember>.from(
        (map['members'] as List).map((m) => RoomMember.fromMap(m)),
      );
    }

    return ChatRoom(
      id: id,
      hostId: map['hostId'] ?? '',
      title: map['title'] ?? '',
      language: map['language'] ?? 'English',
      level: map['level'] ?? 'Any',
      memberCount: map['memberCount']?.toInt() ?? 0,
      maxMembers: map['maxMembers']?.toInt() ?? 5,
      isPaid: map['isPaid'] ?? false,
      isPrivate: map['isPrivate'] ?? false,
      hostName: map['hostName'],
      hostAvatarUrl: map['hostAvatarUrl'],
      liveKitRoomId: map['liveKitRoomId'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      members: memberList,
    );
  }

  // Robust CopyWith for state management updates
  ChatRoom copyWith({
    int? memberCount,
    List<RoomMember>? members,
    String? title,
  }) {
    return ChatRoom(
      id: id,
      hostId: hostId,
      title: title ?? this.title,
      language: language,
      level: level,
      memberCount: memberCount ?? this.memberCount,
      maxMembers: maxMembers,
      members: members ?? this.members,
      createdAt: createdAt,
      isPaid: isPaid,
      isPrivate: isPrivate,
      hostName: hostName,
      hostAvatarUrl: hostAvatarUrl,
      liveKitRoomId: liveKitRoomId,
    );
  }

  @override
  List<Object?> get props => [id, title, memberCount, members, hostId];
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