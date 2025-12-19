import 'package:equatable/equatable.dart';
import 'package:linguaflow/models/speak/room_member.dart';

// ==========================================
// 1. CHAT ROOM MODEL (Free4Talk style)
// ==========================================
class ChatRoom extends Equatable {
  final String id;
  final String hostId;
  final String title;
  final String? description; // Future: Room rules/topic details
  final String language;
  final String level;
  final int memberCount;
  final int maxMembers;
  final bool isPaid;
  final double? entryPrice; // Future: Pay-to-enter rooms
  final bool isPrivate;
  final String? password; // Future: Private rooms with codes
  final String? hostName;
  final String? hostAvatarUrl;
  final List<RoomMember> members;
  final DateTime createdAt;
  final String? liveKitRoomId;
  final List<String> tags; // Future: Search tags like #Anime, #Coding
  final String roomType; // 'audio' or 'video'
  final bool isActive;

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
  });

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
      'members': members.map((m) => m.toMap()).toList(),
      'tags': tags,
      'roomType': roomType,
      'isActive': isActive,
    };
  }

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
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      members: map['members'] != null 
          ? List<RoomMember>.from((map['members'] as List).map((m) => RoomMember.fromMap(m)))
          : [],
      tags: List<String>.from(map['tags'] ?? []),
      roomType: map['roomType'] ?? 'audio',
      isActive: map['isActive'] ?? true,
    );
  }

  ChatRoom copyWith({
    int? memberCount,
    List<RoomMember>? members,
    String? title,
    String? level,
    bool? isActive,
  }) {
    return ChatRoom(
      id: id, hostId: hostId, language: language, createdAt: createdAt,
      title: title ?? this.title,
      level: level ?? this.level,
      memberCount: memberCount ?? this.memberCount,
      members: members ?? this.members,
      isActive: isActive ?? this.isActive,
      maxMembers: maxMembers, isPaid: isPaid, isPrivate: isPrivate,
      hostName: hostName, hostAvatarUrl: hostAvatarUrl, liveKitRoomId: liveKitRoomId,
    );
  }

  @override
  List<Object?> get props => [id, title, memberCount, members, hostId, level, isActive];
}

// ==========================================
// 2. TUTOR LESSON HELPER MODEL
// ==========================================
class TutorLesson extends Equatable {
  final String title;
  final String description;
  final int durationMinutes;
  final double price;

  const TutorLesson({
    required this.title,
    required this.description,
    required this.durationMinutes,
    required this.price,
  });

  Map<String, dynamic> toMap() => {
    'title': title, 'description': description, 'durationMinutes': durationMinutes, 'price': price,
  };

  factory TutorLesson.fromMap(Map<String, dynamic> map) => TutorLesson(
    title: map['title'] ?? '',
    description: map['description'] ?? '',
    durationMinutes: map['durationMinutes'] ?? 60,
    price: (map['price'] as num?)?.toDouble() ?? 0.0,
  );

  @override
  List<Object?> get props => [title, durationMinutes, price];
}

// ==========================================
// 3. TUTOR MODEL (Master Class)
// ==========================================
class Tutor extends Equatable {
  // Basic Info
  final String id;
  final String userId; 
  final String name;
  final String imageUrl;
  final String description;
  final String countryOfBirth;
  final String? timezone;
  final bool isNative;

  // Teaching Stats
  final String language; // Main language
  final String level; // Proficiency
  final List<String> specialties; // IELTS, Business, etc.
  final List<String> otherLanguages; // Other languages they speak
  
  // Performance
  final double rating;
  final int reviews;
  final int totalHoursTaught;
  final int totalStudents;
  final double pricePerHour;
  
  // Verification & Status
  final bool isVerified;
  final bool isSuperTutor;
  final bool isOnline;
  final double profileCompletion; // 0.0 to 1.0

  // Media & Schedules
  final String? introVideoUrl;
  final Map<String, String> availability; // {"Mon": "9AM-5PM"}
  final List<TutorLesson> lessons;
  
  // Future-proofing: Flexible Map for things like social links or trial status
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime? lastUpdatedAt;

  const Tutor({
    required this.id,
    required this.userId,
    required this.name,
    required this.language,
    required this.rating,
    required this.reviews,
    required this.pricePerHour,
    required this.imageUrl,
    required this.level,
    required this.specialties,
    required this.description,
    required this.otherLanguages,
    required this.countryOfBirth,
    required this.isNative,
    required this.availability,
    this.timezone,
    this.totalHoursTaught = 0,
    this.totalStudents = 0,
    this.isVerified = false,
    this.isSuperTutor = false,
    this.isOnline = false,
    this.profileCompletion = 0.5,
    this.introVideoUrl,
    this.lessons = const [],
    this.metadata = const {},
    required this.createdAt,
    this.lastUpdatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId, 
      'name': name,
      'imageUrl': imageUrl,
      'description': description,
      'countryOfBirth': countryOfBirth,
      'timezone': timezone,
      'isNative': isNative,
      'language': language,
      'level': level,
      'specialties': specialties,
      'otherLanguages': otherLanguages,
      'rating': rating,
      'reviews': reviews,
      'totalHoursTaught': totalHoursTaught,
      'totalStudents': totalStudents,
      'pricePerHour': pricePerHour,
      'isVerified': isVerified,
      'isSuperTutor': isSuperTutor,
      'isOnline': isOnline,
      'profileCompletion': profileCompletion,
      'introVideoUrl': introVideoUrl,
      'availability': availability,
      'lessons': lessons.map((l) => l.toMap()).toList(),
      'metadata': metadata,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastUpdatedAt': lastUpdatedAt?.millisecondsSinceEpoch,
    };
  }

  factory Tutor.fromMap(Map<String, dynamic> map, String id) {
    return Tutor(
      id: id,
       userId: map['userId'] ?? '',
       
      name: map['name'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      description: map['description'] ?? '',
      countryOfBirth: map['countryOfBirth'] ?? '',
      timezone: map['timezone'],
      isNative: map['isNative'] ?? false,
      language: map['language'] ?? 'English',
      level: map['level'] ?? 'Native',
      specialties: List<String>.from(map['specialties'] ?? []),
      otherLanguages: List<String>.from(map['otherLanguages'] ?? []),
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      reviews: (map['reviews'] as num?)?.toInt() ?? 0,
      totalHoursTaught: (map['totalHoursTaught'] as num?)?.toInt() ?? 0,
      totalStudents: (map['totalStudents'] as num?)?.toInt() ?? 0,
      pricePerHour: (map['pricePerHour'] as num?)?.toDouble() ?? 0.0,
      isVerified: map['isVerified'] ?? false,
      isSuperTutor: map['isSuperTutor'] ?? false,
      isOnline: map['isOnline'] ?? false,
      profileCompletion: (map['profileCompletion'] as num?)?.toDouble() ?? 0.0,
      introVideoUrl: map['introVideoUrl'],
      availability: Map<String, String>.from(map['availability'] ?? {}),
      lessons: map['lessons'] != null 
          ? List<TutorLesson>.from((map['lessons'] as List).map((l) => TutorLesson.fromMap(l)))
          : [],
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      lastUpdatedAt: map['lastUpdatedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['lastUpdatedAt']) 
          : null,
    );
  }

  Tutor copyWith({
    String? name,
    String? language,
    double? rating,
    int? reviews,
    double? pricePerHour,
    String? imageUrl,
    String? level,
    List<String>? specialties,
    bool? isOnline,
    List<TutorLesson>? lessons,
  }) {
    return Tutor(
      id: id,
      userId: userId,
      name: name ?? this.name,
      language: language ?? this.language,
      rating: rating ?? this.rating,
      reviews: reviews ?? this.reviews,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      imageUrl: imageUrl ?? this.imageUrl,
      level: level ?? this.level,
      specialties: specialties ?? this.specialties,
      description: description,
      otherLanguages: otherLanguages,
      countryOfBirth: countryOfBirth,
      isNative: isNative,
      availability: availability,
      isOnline: isOnline ?? this.isOnline,
      lessons: lessons ?? this.lessons,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name, rating, reviews, isOnline, level, specialties, lessons];
}