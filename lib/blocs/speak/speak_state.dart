import 'package:equatable/equatable.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../models/speak_models.dart';

enum SpeakStatus { initial, loading, success, failure }

// UPDATED: Added 'all' here
enum SpeakTab { all, tutors, rooms }

class SpeakState extends Equatable {
  final SpeakStatus status;
  final SpeakTab currentTab;
  
  // Data Lists
  final List<Tutor> tutors;
  final List<ChatRoom> rooms;
  
  // Filtering (Optional)
  final String? selectedLanguage;

  // Active LiveKit Session (Null if not in a call)
  final Room? activeRoom;

  const SpeakState({
    this.status = SpeakStatus.initial,
    this.currentTab = SpeakTab.all, // Default to 'all'
    this.tutors = const [],
    this.rooms = const [],
    this.selectedLanguage,
    this.activeRoom,
  });

  SpeakState copyWith({
    SpeakStatus? status,
    SpeakTab? currentTab,
    List<Tutor>? tutors,
    List<ChatRoom>? rooms,
    String? selectedLanguage,
    Room? activeRoom,
    bool clearActiveRoom = false,
  }) {
    return SpeakState(
      status: status ?? this.status,
      currentTab: currentTab ?? this.currentTab,
      tutors: tutors ?? this.tutors,
      rooms: rooms ?? this.rooms,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      activeRoom: clearActiveRoom ? null : (activeRoom ?? this.activeRoom),
    );
  }

  @override
  List<Object?> get props => [status, currentTab, tutors, rooms, selectedLanguage, activeRoom];
}