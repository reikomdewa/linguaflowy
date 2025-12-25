import 'package:linguaflow/models/speak/speak_models.dart';

enum SessionType {
  socialRoom,
  tutorClass,
}

class LiveSessionConfig {
  final String id;              // Room ID or Tutor ID
  final String title;           // "English Practice" or "John's Class"
  final String hostId;
  final String? hostName;
  final String? hostAvatar;
  final SessionType type;       // To toggle specific UI (like "Rate Tutor")
  final String firestorePath;   // 'rooms' or 'tutors/sessions'

  // Capabilities
  final bool isHost;
  final bool allowSpotlight;
  
  const LiveSessionConfig({
    required this.id,
    required this.title,
    required this.hostId,
    required this.type,
    required this.firestorePath,
    required this.isHost,
    this.hostName,
    this.hostAvatar,
    this.allowSpotlight = true,
  });

  // FACTORY 1: Create from a ChatRoom
  factory LiveSessionConfig.fromRoom(ChatRoom room, String currentUserId) {
    return LiveSessionConfig(
      id: room.id,
      title: room.title,
      hostId: room.hostId,
      hostName: room.hostName,
      hostAvatar: room.hostAvatarUrl,
      type: SessionType.socialRoom,
      firestorePath: 'rooms', // Listens to 'rooms' collection
      isHost: room.hostId == currentUserId,
    );
  }

  // FACTORY 2: Create from a Tutor
  factory LiveSessionConfig.fromTutor(Tutor tutor, String currentUserId) {
    return LiveSessionConfig(
      id: tutor.id, // Or a specific session ID
      title: "${tutor.name}'s Class",
      hostId: tutor.userId,
      hostName: tutor.name,
      hostAvatar: tutor.imageUrl,
      type: SessionType.tutorClass,
      firestorePath: 'tutor_sessions', // Listens to a different collection if needed
      isHost: tutor.userId == currentUserId,
    );
  }
}