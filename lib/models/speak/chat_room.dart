import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'room_member.dart';

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
  final DateTime createdAt;
  final DateTime? expireAt;
  final DateTime? lastUpdatedAt;
  final String? liveKitRoomId;
  final List<String> tags;
  final String roomType;
  final bool isActive;
  final String? spotlightedUserId;

  // --- NEW FIELDS FOR FEATURES ---
  final String? activeFeature; // 'whiteboard', 'youtube', 'none'
  final String? activeFeatureData; // e.g. YouTube URL
   final List<String>? boardRequests; 

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
    this.expireAt,
    this.lastUpdatedAt,
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
    this.activeFeature,
    this.activeFeatureData,
     this.boardRequests,
  });

  // Helper getters for UI
  List<RoomMember> get displayMembers => members.take(10).toList();
  int get othersCount => memberCount > 10 ? memberCount - 10 : 0;

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
      'createdAt': createdAt.millisecondsSinceEpoch,
      'expireAt': expireAt?.millisecondsSinceEpoch,
      'lastUpdatedAt': lastUpdatedAt?.millisecondsSinceEpoch,
      'members': members.map((m) => m.toMap()).toList(),
      'tags': tags,
      'roomType': roomType,
      'isActive': isActive,
      'spotlightedUserId': spotlightedUserId,
      // New Fields
      'activeFeature': activeFeature,
      'activeFeatureData': activeFeatureData,
       "boardRequests": boardRequests,
      
    };
  }

  factory ChatRoom.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return null;
    }

    List<RoomMember> parsedMembers = [];
    if (map['members'] != null && map['members'] is List) {
      try {
        parsedMembers = (map['members'] as List)
            .map((m) {
              if (m == null) return null;
              try {
                if (m is Map<String, dynamic>) return RoomMember.fromMap(m);
                if (m is Map)
                  return RoomMember.fromMap(Map<String, dynamic>.from(m));
              } catch (e) {}
              return null;
            })
            .where((m) => m != null)
            .cast<RoomMember>()
            .toList();
      } catch (e) {
        parsedMembers = [];
      }
    }

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
      createdAt: parseDate(map['createdAt']),
      expireAt: parseNullableDate(map['expireAt']),
      lastUpdatedAt: parseNullableDate(map['lastUpdatedAt']),
      members: parsedMembers,
      tags: List<String>.from(map['tags'] ?? []),
      roomType: map['roomType'] ?? 'audio',
      isActive: map['isActive'] ?? true,
      spotlightedUserId: map['spotlightedUserId'],
      // New Fields
      activeFeature: map['activeFeature'],
      activeFeatureData: map['activeFeatureData'],
       boardRequests: map['boardRequests'] != null 
          ? List<String>.from(map['boardRequests']) 
          : [],
    );
  }

  ChatRoom copyWith({
    String? title,
    String? description,
    String? language,
    String? level,
    int? memberCount,
    int? maxMembers,
    List<RoomMember>? members,
    bool? isActive,
    String? spotlightedUserId,
    DateTime? lastUpdatedAt,
    DateTime? expireAt,
    bool? isPaid,
    bool? isPrivate,
    String? hostName,
    String? hostAvatarUrl,
    String? liveKitRoomId,
    String? activeFeature,
    String? activeFeatureData,
  }) {
    return ChatRoom(
      id: id,
      hostId: hostId,
      createdAt: createdAt,
      title: title ?? this.title,
      description: description ?? this.description,
      language: language ?? this.language,
      level: level ?? this.level,
      memberCount: memberCount ?? this.memberCount,
      maxMembers: maxMembers ?? this.maxMembers,
      members: members ?? this.members,
      isActive: isActive ?? this.isActive,
      spotlightedUserId: spotlightedUserId ?? this.spotlightedUserId,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      expireAt: expireAt ?? this.expireAt,
      isPaid: isPaid ?? this.isPaid,
      entryPrice: entryPrice,
      isPrivate: isPrivate ?? this.isPrivate,
      password: password,
      hostName: hostName ?? this.hostName,
      hostAvatarUrl: hostAvatarUrl ?? this.hostAvatarUrl,
      liveKitRoomId: liveKitRoomId ?? this.liveKitRoomId,
      tags: tags,
      roomType: roomType,
      // New Fields
      activeFeature: activeFeature ?? this.activeFeature,
      activeFeatureData: activeFeatureData ?? this.activeFeatureData,
    );
  }

  @override
  List<Object?> get props => [
    id,
    hostId,
    title,
    memberCount,
    members,
    level,
    isActive,
    spotlightedUserId,
    lastUpdatedAt,
    expireAt,
    liveKitRoomId,
    activeFeature,
    activeFeatureData,
  ];
}