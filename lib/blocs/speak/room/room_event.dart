import 'package:equatable/equatable.dart';
import 'package:linguaflow/models/speak/speak_models.dart';
import 'package:livekit_client/livekit_client.dart'; // Essential for media

abstract class RoomEvent extends Equatable {
  const RoomEvent();
  @override
  List<Object?> get props => [];
}

// ==========================================
// DATA & FILTERING
// ==========================================

class LoadRooms extends RoomEvent {
  final bool isRefresh;
  const LoadRooms({this.isRefresh = false});
}

class RoomsUpdated extends RoomEvent {
  final List<ChatRoom> rooms;
  const RoomsUpdated(this.rooms);
  @override
  List<Object?> get props => [rooms];
}

class FilterRooms extends RoomEvent {
  final String? query; 
  final String? category; // e.g., 'Language Level', 'Paid'
  const FilterRooms(this.query, {this.category});
  @override
  List<Object?> get props => [query, category];
}

class ClearRoomFilters extends RoomEvent {}

// ==========================================
// CRUD (CREATE / DELETE)
// ==========================================

class CreateRoomEvent extends RoomEvent {
  // We keep the individual fields so your UI doesn't break
  final String topic;
  final String? description;
  final String language;
  final String level;
  final int maxMembers;
  final bool isPaid;
  final double? entryPrice;
  final bool isPrivate;
  final String? password;
  final List<String> tags;
  final String roomType;

  const CreateRoomEvent({
    required this.topic,
    this.description,
    required this.language,
    required this.level,
    required this.maxMembers,
    required this.isPaid,
    this.entryPrice,
    this.isPrivate = false,
    this.password,
    this.tags = const [],
    this.roomType = 'audio',
  });

  @override
  List<Object?> get props => [topic, language, level, isPaid, isPrivate, tags];
}

class DeleteRoomEvent extends RoomEvent {
  final String roomId;
  const DeleteRoomEvent(this.roomId);
  @override
  List<Object?> get props => [roomId];
}

// ==========================================
// LIVEKIT & INTERACTION
// ==========================================

class JoinRoomEvent extends RoomEvent {
  final ChatRoom room;
  const JoinRoomEvent(this.room);
  @override
  List<Object> get props => [room];
}

// Triggered when LiveKit actually connects
class RoomJoined extends RoomEvent {
  final Room room; // LiveKit Room Object
  const RoomJoined(this.room);
  @override
  List<Object?> get props => [room];
}

class LeaveRoomEvent extends RoomEvent {}

// ==========================================
// MODERATION
// ==========================================

class ToggleSpotlightEvent extends RoomEvent {
  final String roomId;
  final String? userId; // MUST be nullable
  const ToggleSpotlightEvent({required this.roomId, this.userId});
  @override
  List<Object?> get props => [roomId, userId];
}

class KickUserEvent extends RoomEvent {
  final String roomId;
  final String userId; 
  const KickUserEvent({required this.roomId, required this.userId});
  @override
  List<Object?> get props => [roomId, userId];
}


// Add these to your existing RoomEvent file

// 1. Host updates Title/Description
class UpdateRoomInfoEvent extends RoomEvent {
  final String roomId;
  final String title;
  final String description;

  const UpdateRoomInfoEvent({
    required this.roomId,
    required this.title,
    required this.description,
  });
  
  @override
  List<Object?> get props => [roomId, title, description];
}

// 2. Host toggles Whiteboard or YouTube
class UpdateActiveFeatureEvent extends RoomEvent {
  final String roomId;
  final String feature; // 'whiteboard', 'youtube', 'none'
  final String? data;   // YouTube Link

  const UpdateActiveFeatureEvent({
    required this.roomId,
    required this.feature,
    this.data,
  });

  @override
  List<Object?> get props => [roomId, feature, data];
}

// ... existing imports

// --- BOARD REQUEST LOGIC ---

// User asks to share their board
class RequestBoardAccessEvent extends RoomEvent {
  final String roomId;
  final String userId;
  const RequestBoardAccessEvent({required this.roomId, required this.userId});
  @override
  List<Object?> get props => [roomId, userId];
}

// User cancels request
class CancelBoardRequestEvent extends RoomEvent {
  final String roomId;
  final String userId;
  const CancelBoardRequestEvent({required this.roomId, required this.userId});
  @override
  List<Object?> get props => [roomId, userId];
}

// Host accepts a user (Sets activeFeature = 'whiteboard' & activeFeatureData = userId)
class GrantBoardAccessEvent extends RoomEvent {
  final String roomId;
  final String targetUserId; // The user who will stream
  const GrantBoardAccessEvent({required this.roomId, required this.targetUserId});
  @override
  List<Object?> get props => [roomId, targetUserId];
}

// Host closes the board (Switch to Tiles)
class StopBoardSharingEvent extends RoomEvent {
  final String roomId;
  const StopBoardSharingEvent(this.roomId);
  @override
  List<Object?> get props => [roomId];
}

// ... existing imports

// --- YOUTUBE LOGIC ---

// 1. Guest asks to play a video
class RequestYouTubeAccessEvent extends RoomEvent {
  final String roomId;
  final String userId;
  final String videoUrl; // <--- NEW

  const RequestYouTubeAccessEvent({
    required this.roomId, 
    required this.userId,
    required this.videoUrl
  });
  @override
  List<Object?> get props => [roomId, userId, videoUrl];
}


class CancelYouTubeRequestEvent extends RoomEvent {
  final String roomId;
  final Map<String, dynamic> requestMap; // We need the object to remove it

  const CancelYouTubeRequestEvent({required this.roomId, required this.requestMap});
  @override
  List<Object?> get props => [roomId, requestMap];
}

// 3. HOST plays a video (Updates feature to 'youtube' & sets the Link)
class PlayYouTubeVideoEvent extends RoomEvent {
  final String roomId;
  final String videoUrl;
  final Map<String, dynamic>? requestToRemove; // <--- NEW

  const PlayYouTubeVideoEvent({
    required this.roomId, 
    required this.videoUrl,
    this.requestToRemove,
  });

  @override
  List<Object?> get props => [roomId, videoUrl, requestToRemove];
}
// 4. Stop YouTube (Switch back to none)
class StopYouTubeEvent extends RoomEvent {
  final String roomId;
  const StopYouTubeEvent(this.roomId);
  @override
  List<Object?> get props => [roomId];
}

// ... inside room_event.dart

// Host syncs player state (Play, Pause, Seek)
class SyncYouTubeStateEvent extends RoomEvent {
  final String roomId;
  final String status; // 'playing' or 'paused'
  final int positionSeconds; // Current timestamp in video

  const SyncYouTubeStateEvent({
    required this.roomId,
    required this.status,
    required this.positionSeconds,
  });

  @override
  List<Object?> get props => [roomId, status, positionSeconds];
}