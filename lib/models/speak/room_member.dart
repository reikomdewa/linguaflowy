import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    // Helper to safely parse dates from either Firestore Timestamp or integer
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      // Handle cases where timestamp might be null, default to now
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    return RoomMember(
      uid: map['uid'] as String? ?? '',
      displayName: map['displayName'] as String?,
      avatarUrl: map['avatarUrl'] as String?,
      joinedAt: parseDate(map['joinedAt']),
      isHost: map['isHost'] as bool? ?? false,

      // --- CRITICAL FIX FOR XP ---
      // This safely handles null, int, and double values from Firestore.
      // 1. Casts the value to a generic 'num' (or null).
      // 2. If it's not null, converts it to an integer.
      xp: (map['xp'] as num?)?.toInt(),
    );
  }

  @override
  List<Object?> get props => [uid, displayName, avatarUrl, joinedAt, isHost, xp];
}