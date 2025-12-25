import 'package:equatable/equatable.dart';
import 'package:linguaflow/models/speak/speak_models.dart';
import 'package:livekit_client/livekit_client.dart'; // Keep for the LiveKit Room object

enum RoomStatus { initial, loading, success, failure }

class RoomState extends Equatable {
  final RoomStatus status;
  final List<ChatRoom> allRooms;       // The master list from Firestore stream
  final List<ChatRoom> filteredRooms;  // The list actually displayed in UI after filters
  final Map<String, String> filters;   // Filters applied to rooms
  final String searchQuery;            // Search query for rooms
  final Room? activeLivekitRoom;       // The LiveKit Room object (not your ChatRoom model)
  final ChatRoom? activeChatRoom;      // Your ChatRoom model for the active room

  const RoomState({
    this.status = RoomStatus.initial,
    this.allRooms = const [],
    this.filteredRooms = const [],
    this.filters = const {},
    this.searchQuery = '',
    this.activeLivekitRoom,
    this.activeChatRoom,
  });

  RoomState copyWith({
    RoomStatus? status,
    List<ChatRoom>? allRooms,
    List<ChatRoom>? filteredRooms,
    Map<String, String>? filters,
    String? searchQuery,
    Room? activeLivekitRoom,
    ChatRoom? activeChatRoom,
    bool clearActiveLivekitRoom = false, // Special flag to clear active room
    bool clearActiveChatRoom = false,
    bool resetFilters = false,           // Special flag to reset filters
  }) {
    return RoomState(
      status: status ?? this.status,
      allRooms: allRooms ?? this.allRooms,
      filteredRooms: filteredRooms ?? this.filteredRooms,
      filters: resetFilters ? const {} : (filters ?? this.filters),
      searchQuery: resetFilters ? '' : (searchQuery ?? this.searchQuery),
      activeLivekitRoom: clearActiveLivekitRoom ? null : (activeLivekitRoom ?? this.activeLivekitRoom),
      activeChatRoom: clearActiveChatRoom ? null : (activeChatRoom ?? this.activeChatRoom),
    );
  }

  @override
  List<Object?> get props => [
        status,
        allRooms,
        filteredRooms,
        filters,
        searchQuery,
        activeLivekitRoom,
        activeChatRoom,
      ];
}