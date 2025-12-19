import 'package:equatable/equatable.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../models/speak/speak_models.dart';

enum SpeakStatus { initial, loading, success, failure }
enum SpeakTab { all, tutors, rooms }

class SpeakState extends Equatable {
  final SpeakStatus status;
  final SpeakTab currentTab;
  final List<Tutor> tutors;
  final List<ChatRoom> rooms;
  final String? searchQuery;
  final Map<String, String> filters; // <--- ADDED THIS
  final Room? activeRoom;

  const SpeakState({
    this.status = SpeakStatus.initial,
    this.currentTab = SpeakTab.all,
    this.tutors = const [],
    this.rooms = const [],
    this.searchQuery,
    this.filters = const {}, // <--- INITIALIZED AS EMPTY
    this.activeRoom,
  });

  SpeakState copyWith({
    SpeakStatus? status,
    SpeakTab? currentTab,
    List<Tutor>? tutors,
    List<ChatRoom>? rooms,
    String? searchQuery,
    Map<String, String>? filters, // <--- ADDED THIS
    Room? activeRoom,
    bool clearActiveRoom = false,
    bool resetFilters = false,
  }) {
    return SpeakState(
      status: status ?? this.status,
      currentTab: currentTab ?? this.currentTab,
      tutors: tutors ?? this.tutors,
      rooms: rooms ?? this.rooms,
      searchQuery: resetFilters ? null : (searchQuery ?? this.searchQuery),
      filters: resetFilters ? const {} : (filters ?? this.filters), // <--- LOGIC ADDED
      activeRoom: clearActiveRoom ? null : (activeRoom ?? this.activeRoom),
    );
  }

  @override
  List<Object?> get props => [
        status,
        currentTab,
        tutors,
        rooms,
        searchQuery,
        filters, // <--- ADDED THIS
        activeRoom,
      ];
}