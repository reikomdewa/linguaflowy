import 'package:equatable/equatable.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../models/speak_models.dart';

abstract class SpeakEvent extends Equatable {
  const SpeakEvent();

  @override
  List<Object?> get props => [];
}

class LoadSpeakData extends SpeakEvent {}

class ChangeSpeakTab extends SpeakEvent {
  final int tabIndex;
  const ChangeSpeakTab(this.tabIndex);

  @override
  List<Object?> get props => [tabIndex];
}

class FilterSpeakList extends SpeakEvent {
  final String? language;
  const FilterSpeakList({this.language});
}

// --- LiveKit Room Management ---
class RoomJoined extends SpeakEvent {
  final Room room;
  const RoomJoined(this.room);
  @override
  List<Object?> get props => [room];
}

class RoomLeft extends SpeakEvent {}

// --- CREATION EVENTS ---

class CreateRoomEvent extends SpeakEvent {
  final String topic;
  final String language;
  final String level;
  final int maxMembers;
  final bool isPaid;

  const CreateRoomEvent({
    required this.topic,
    required this.language,
    required this.level,
    required this.maxMembers,
    required this.isPaid,
  });

  @override
  List<Object?> get props => [topic, language, level, maxMembers, isPaid];
}

class CreateTutorProfileEvent extends SpeakEvent {
  final String name;
  final String language;
  final double pricePerHour;
  final String imageUrl;

  const CreateTutorProfileEvent({
    required this.name,
    required this.language,
    required this.pricePerHour,
    required this.imageUrl,
  });

  @override
  List<Object?> get props => [name, language, pricePerHour, imageUrl];
}
class JoinRoomEvent extends SpeakEvent {
  final ChatRoom room;
  const JoinRoomEvent(this.room);

  @override
  List<Object> get props => [room];
}