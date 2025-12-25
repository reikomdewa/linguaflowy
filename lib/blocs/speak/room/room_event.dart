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
  final String? userId; 
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