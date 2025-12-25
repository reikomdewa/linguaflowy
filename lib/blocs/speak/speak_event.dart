// import 'package:equatable/equatable.dart';
// import 'package:livekit_client/livekit_client.dart'; // Essential for media
// import 'package:linguaflow/models/speak/speak_models.dart';

// abstract class SpeakEvent extends Equatable {
//   const SpeakEvent();

//   @override
//   List<Object?> get props => [];
// }

// // ==========================================
// // 1. DATA LOADING & UI EVENTS
// // ==========================================

// class LoadSpeakData extends SpeakEvent {
//   final bool isRefresh;
//   const LoadSpeakData({this.isRefresh = false});

//   @override
//   List<Object?> get props => [isRefresh];
// }

// class ChangeSpeakTab extends SpeakEvent {
//   final int tabIndex; // 0: All, 1: Tutors, 2: Rooms
//   const ChangeSpeakTab(this.tabIndex);

//   @override
//   List<Object?> get props => [tabIndex];
// }

// // ==========================================
// // 2. FILTERING & SEARCH EVENTS
// // ==========================================

// class FilterSpeakList extends SpeakEvent {
//   final String? query; // Search text
//   final String? category; // e.g., 'Language Level', 'Specialty', 'Paid'
//   const FilterSpeakList(this.query, {this.category});

//   @override
//   List<Object?> get props => [query, category];
// }

// class ClearAllFilters extends SpeakEvent {}

// // ==========================================
// // 3. ROOM MANAGEMENT & MEDIA EVENTS
// // ==========================================

// class CreateRoomEvent extends SpeakEvent {
//   final String topic;
//   final String? description;
//   final String language;
//   final String level;
//   final int maxMembers;
//   final bool isPaid;
//   final double? entryPrice;
//   final bool isPrivate;
//   final String? password;
//   final List<String> tags;
//   final String roomType; // 'audio' or 'video'

//   const CreateRoomEvent({
//     required this.topic,
//     this.description,
//     required this.language,
//     required this.level,
//     required this.maxMembers,
//     required this.isPaid,
//     this.entryPrice,
//     this.isPrivate = false,
//     this.password,
//     this.tags = const [],
//     this.roomType = 'audio',
//   });

//   @override
//   List<Object?> get props => [topic, language, level, isPaid, isPrivate, tags];
// }
// // Add these to your speak_event.dart file
// class DeleteTutorProfileEvent extends SpeakEvent {
//   final String tutorId;
//   const DeleteTutorProfileEvent(this.tutorId);
//   @override
//   List<Object?> get props => [tutorId];
// }

// class DeleteRoomEvent extends SpeakEvent {
//   final String roomId;
//   const DeleteRoomEvent(this.roomId);
//   @override
//   List<Object?> get props => [roomId];
// }
// class JoinRoomEvent extends SpeakEvent {
//   final ChatRoom room;
//   const JoinRoomEvent(this.room);

//   @override
//   List<Object> get props => [room];
// }

// /// This event handles the LiveKit Room connection status
// class RoomJoined extends SpeakEvent {
//   final Room room; // This is the LiveKit Room object
//   const RoomJoined(this.room);

//   @override
//   List<Object?> get props => [room];
// }

// class LeaveRoomEvent extends SpeakEvent {}

// // ==========================================
// // 4. TUTOR MANAGEMENT EVENTS
// // ==========================================

// class CreateTutorProfileEvent extends SpeakEvent {
//   // Essential Info
//   final String name;
//   final String description;
//   final String imageUrl;
//   final String countryOfBirth;
//   final bool isNative;
//   final String language;
//   final String level;
//   final double pricePerHour;
  
//   // Complex Structures
//   final List<String> specialties;
//   final List<String> otherLanguages;
//   final Map<String, String> availability;
//   final List<TutorLesson> lessons;
  
//   // Future Metadata (Social links, YouTube ID, etc)
//   final Map<String, dynamic> metadata;

//   const CreateTutorProfileEvent({
//     required this.name,
//     required this.description,
//     required this.imageUrl,
//     required this.countryOfBirth,
//     required this.isNative,
//     required this.language,
//     required this.level,
//     required this.pricePerHour,
//     required this.specialties,
//     required this.otherLanguages,
//     required this.availability,
//     required this.lessons,
//     this.metadata = const {},
//   });

//   @override
//   List<Object?> get props => [
//     name, 
//     language, 
//     pricePerHour, 
//     isNative, 
//     level, 
//     specialties, 
//     availability, 
//     lessons
//   ];
// }

// class UpdateTutorProfileEvent extends CreateTutorProfileEvent {
//   const UpdateTutorProfileEvent({
//     required super.name,
//     required super.description,
//     required super.imageUrl,
//     required super.countryOfBirth,
//     required super.isNative,
//     required super.language,
//     required super.level,
//     required super.pricePerHour,
//     required super.specialties,
//     required super.otherLanguages,
//     required super.availability,
//     required super.lessons,
//     super.metadata,
//   });
// }

// class ToggleFavoriteTutor extends SpeakEvent {
//   final String tutorId;
//   const ToggleFavoriteTutor(this.tutorId);

//   @override
//   List<Object?> get props => [tutorId];
// }

// // ==========================================
// // 5. BOOKING & INTERACTION EVENTS
// // ==========================================

// class BookLessonEvent extends SpeakEvent {
//   final Tutor tutor;
//   final TutorLesson lesson;
//   final DateTime scheduledTime;

//   const BookLessonEvent({
//     required this.tutor,
//     required this.lesson,
//     required this.scheduledTime,
//   });

//   @override
//   List<Object?> get props => [tutor, lesson, scheduledTime];
// }

// class ToggleSpotlightEvent extends SpeakEvent {
//   final String roomId;
//   final String? userId; // Pass null to turn off spotlight, or userId to turn on

//   const ToggleSpotlightEvent({required this.roomId, this.userId});

//   @override
//   List<Object?> get props => [roomId, userId];
// }
// class KickUserEvent extends SpeakEvent {
//   final String roomId;
//   final String userId; // The LiveKit Identity (name or uid) to kick

//   const KickUserEvent({required this.roomId, required this.userId});

//   @override
//   List<Object?> get props => [roomId, userId];
// }

// class RoomsUpdatedEvent extends SpeakEvent {
//   final List<ChatRoom> rooms;
//   const RoomsUpdatedEvent(this.rooms);

//   @override
//   List<Object?> get props => [rooms];
// }
