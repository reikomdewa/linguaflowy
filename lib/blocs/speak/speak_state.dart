import 'package:equatable/equatable.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../models/speak_models.dart';

enum SpeakStatus { initial, loading, success, failure }
enum SpeakTab { all, tutors, rooms }

class SpeakState extends Equatable {
  final SpeakStatus status;
  final SpeakTab currentTab;
  final List<Tutor> tutors;
  final List<ChatRoom> rooms;
  final String? searchQuery;
  final String? activeCategory;
  final Room? activeRoom;

  const SpeakState({
    this.status = SpeakStatus.initial,
    this.currentTab = SpeakTab.all,
    this.tutors = const [],
    this.rooms = const [],
    this.searchQuery,
    this.activeCategory,
    this.activeRoom,
  });

  SpeakState copyWith({
    SpeakStatus? status,
    SpeakTab? currentTab,
    List<Tutor>? tutors,
    List<ChatRoom>? rooms,
    String? searchQuery,
    String? activeCategory,
    Room? activeRoom,
    bool clearActiveRoom = false,
    bool clearFilters = false,
  }) {
    return SpeakState(
      status: status ?? this.status,
      currentTab: currentTab ?? this.currentTab,
      tutors: tutors ?? this.tutors,
      rooms: rooms ?? this.rooms,
      searchQuery: clearFilters ? null : (searchQuery ?? this.searchQuery),
      activeCategory: clearFilters ? null : (activeCategory ?? this.activeCategory),
      activeRoom: clearActiveRoom ? null : (activeRoom ?? this.activeRoom),
    );
  }

  @override
  List<Object?> get props => [status, currentTab, tutors, rooms, searchQuery, activeCategory, activeRoom];
}