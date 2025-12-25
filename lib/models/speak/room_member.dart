import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add Import

class RoomMember extends Equatable {
  final String uid;
  final String? displayName;
  final String? avatarUrl;
  final DateTime joinedAt;
  final bool isHost;
  final int? xp;

  const RoomMember({
    required this.uid,
    this.displayName,
    this.avatarUrl,
    required this.joinedAt,
    this.isHost = false,
    this.xp,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'joinedAt': joinedAt.millisecondsSinceEpoch,
      'isHost': isHost,
      'xp': xp,
    };
  }

  factory RoomMember.fromMap(Map<String, dynamic> map) {
    // Robust Date Parser
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    return RoomMember(
      uid: map['uid'] ?? '',
      displayName: map['displayName'],
      avatarUrl: map['avatarUrl'],
      joinedAt: parseDate(map['joinedAt']), // <--- FIXED
      isHost: map['isHost'] ?? false,
      xp: map['xp'],
    );
  }

  @override
  List<Object?> get props => [uid, displayName, isHost, xp];
}