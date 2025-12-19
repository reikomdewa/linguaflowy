import 'package:equatable/equatable.dart';

class RoomMember extends Equatable {
  final String uid;
  final String? displayName;
  final String? avatarUrl;
  final DateTime joinedAt;
  final bool isHost;

  const RoomMember({
    required this.uid,
    this.displayName,
    this.avatarUrl,
    required this.joinedAt,
    this.isHost = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'joinedAt': joinedAt.millisecondsSinceEpoch,
      'isHost': isHost,
    };
  }

  factory RoomMember.fromMap(Map<String, dynamic> map) {
    return RoomMember(
      uid: map['uid'] ?? '',
      displayName: map['displayName'],
      avatarUrl: map['avatarUrl'],
      joinedAt: DateTime.fromMillisecondsSinceEpoch(map['joinedAt'] ?? 0),
      isHost: map['isHost'] ?? false,
    );
  }

  @override
  List<Object?> get props => [uid, isHost];
}