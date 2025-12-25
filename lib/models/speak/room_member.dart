import 'package:equatable/equatable.dart';

class RoomMember extends Equatable {
  final String uid;
  final String? displayName;
  final String? avatarUrl;
  final DateTime joinedAt;
  final bool isHost;
  final int xp; // <--- Added XP field

  const RoomMember({
    required this.uid,
    this.displayName,
    this.avatarUrl,
    required this.joinedAt,
    this.isHost = false,
    this.xp = 0, // <--- Default to 0
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'joinedAt': joinedAt.millisecondsSinceEpoch,
      'isHost': isHost,
      'xp': xp, // <--- Add to Map
    };
  }

  factory RoomMember.fromMap(Map<String, dynamic> map) {
    return RoomMember(
      uid: map['uid'] ?? '',
      displayName: map['displayName'],
      avatarUrl: map['avatarUrl'],
      joinedAt: DateTime.fromMillisecondsSinceEpoch(map['joinedAt'] ?? 0),
      isHost: map['isHost'] ?? false,
      // Safely parse int from Firestore (which handles numbers as 'num')
      xp: (map['xp'] as num?)?.toInt() ?? 0, 
    );
  }

  // Optional: CopyWith is useful if you need to update a member's XP locally
  RoomMember copyWith({
    String? uid,
    String? displayName,
    String? avatarUrl,
    DateTime? joinedAt,
    bool? isHost,
    int? xp,
  }) {
    return RoomMember(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      joinedAt: joinedAt ?? this.joinedAt,
      isHost: isHost ?? this.isHost,
      xp: xp ?? this.xp,
    );
  }

  @override
  List<Object?> get props => [uid, isHost, xp, displayName, avatarUrl];
}