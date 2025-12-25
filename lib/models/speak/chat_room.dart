// ==========================================
// 1. CHAT ROOM MODEL
// ==========================================
import 'package:equatable/equatable.dart';
import 'package:linguaflow/models/speak/room_member.dart';

class ChatRoom extends Equatable {
  final String id;
  final String hostId;
  final String title;
  final String? description;
  final String language;
  final String level;
  final int memberCount;
  final int maxMembers;
  final bool isPaid;
  final double? entryPrice;
  final bool isPrivate;
  final String? password;
  final String? hostName;
  final String? hostAvatarUrl;
  final List<RoomMember> members;

  // --- TIMESTAMPS FOR CLEANUP ---
  final DateTime createdAt;
  final DateTime? expireAt; // For Firebase TTL (Auto-delete)
  final DateTime? lastUpdatedAt; // For "Ghost Room" logic
  // ------------------------------

  final String? liveKitRoomId;
  final List<String> tags;
  final String roomType; // 'audio' or 'video'
  final bool isActive;
  final String? spotlightedUserId;

  const ChatRoom({
    required this.id,
    required this.hostId,
    required this.title,
    this.description,
    required this.language,
    required this.level,
    required this.memberCount,
    required this.maxMembers,
    required this.members,
    required this.createdAt,
    this.expireAt, // Changed to Nullable
    this.lastUpdatedAt, // Added
    this.isPaid = false,
    this.entryPrice,
    this.isPrivate = false,
    this.password,
    this.hostName,
    this.hostAvatarUrl,
    this.liveKitRoomId,
    this.tags = const [],
    this.roomType = 'audio',
    this.isActive = true,
    this.spotlightedUserId,
  });

  List<RoomMember> get displayMembers => members.take(10).toList();
  int get othersCount => memberCount > 10 ? memberCount - 10 : 0;

  // ---------------------------------------------------------------------------
  // TO MAP (Saving to Firestore)
  // ---------------------------------------------------------------------------
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hostId': hostId,
      'title': title,
      'description': description,
      'language': language,
      'level': level,
      'memberCount': memberCount,
      'maxMembers': maxMembers,
      'isPaid': isPaid,
      'entryPrice': entryPrice,
      'isPrivate': isPrivate,
      'password': password,
      'hostName': hostName,
      'hostAvatarUrl': hostAvatarUrl,
      'liveKitRoomId': liveKitRoomId ?? id,

      // Timestamps
      'createdAt': createdAt.millisecondsSinceEpoch,
      'expireAt': expireAt?.millisecondsSinceEpoch, // <--- FIXED
      'lastUpdatedAt': lastUpdatedAt?.millisecondsSinceEpoch, // <--- FIXED

      'members': members.map((m) => m.toMap()).toList(),
      'tags': tags,
      'roomType': roomType,
      'isActive': isActive,
      'spotlightedUserId': spotlightedUserId,
    };
  }

  // ---------------------------------------------------------------------------
  // FROM MAP (Loading from Firestore)
  // ---------------------------------------------------------------------------
  factory ChatRoom.fromMap(Map<String, dynamic> map, String id) {
    return ChatRoom(
      id: id,
      hostId: map['hostId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'],
      language: map['language'] ?? 'English',
      level: map['level'] ?? 'Any',
      memberCount: (map['memberCount'] as num?)?.toInt() ?? 0,
      maxMembers: (map['maxMembers'] as num?)?.toInt() ?? 5,
      isPaid: map['isPaid'] ?? false,
      entryPrice: (map['entryPrice'] as num?)?.toDouble(),
      isPrivate: map['isPrivate'] ?? false,
      password: map['password'],
      hostName: map['hostName'],
      hostAvatarUrl: map['hostAvatarUrl'],
      liveKitRoomId: map['liveKitRoomId'],

      // Timestamps
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      expireAt: map['expireAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['expireAt'])
          : null,
      lastUpdatedAt: map['lastUpdatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastUpdatedAt'])
          : null,

      members: map['members'] != null
          ? List<RoomMember>.from(
              (map['members'] as List).map((m) => RoomMember.fromMap(m)),
            )
          : [],
      tags: List<String>.from(map['tags'] ?? []),
      roomType: map['roomType'] ?? 'audio',
      isActive: map['isActive'] ?? true,
      spotlightedUserId: map['spotlightedUserId'],
    );
  }

  // ---------------------------------------------------------------------------
  // COPY WITH (Updating State)
  // ---------------------------------------------------------------------------
  ChatRoom copyWith({
    int? memberCount,
    List<RoomMember>? members,
    String? title,
    String? level,
    bool? isActive,
    String? spotlightedUserId,
    DateTime? lastUpdatedAt, // Added
    DateTime? expireAt, // Added
  }) {
    return ChatRoom(
      id: id,
      hostId: hostId,
      language: language,
      createdAt: createdAt,
      // Updates
      title: title ?? this.title,
      level: level ?? this.level,
      memberCount: memberCount ?? this.memberCount,
      members: members ?? this.members,
      isActive: isActive ?? this.isActive,
      spotlightedUserId: spotlightedUserId ?? this.spotlightedUserId,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      expireAt: expireAt ?? this.expireAt,
      // Existing
      maxMembers: maxMembers,
      isPaid: isPaid,
      isPrivate: isPrivate,
      hostName: hostName,
      hostAvatarUrl: hostAvatarUrl,
      liveKitRoomId: liveKitRoomId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    memberCount,
    members,
    hostId,
    level,
    isActive,
    spotlightedUserId,
    lastUpdatedAt,
    expireAt,
  ];
}
