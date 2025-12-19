import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/models/room_member.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'speak_event.dart';
import 'speak_state.dart';
import '../../models/speak_models.dart';
import '../../services/speak/speak_service.dart';

class SpeakBloc extends Bloc<SpeakEvent, SpeakState> {
  final _uuid = const Uuid();
  final SpeakService _speakService = SpeakService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Master lists to filter against
  List<ChatRoom> _masterRooms = [];
  List<Tutor> _masterTutors = [];

  SpeakBloc() : super(const SpeakState()) {
    on<LoadSpeakData>(_onLoadSpeakData);
    on<ChangeSpeakTab>(_onChangeSpeakTab);
    on<FilterSpeakList>(_onFilterSpeakList);
    on<ClearAllFilters>(_onClearAllFilters);
    on<RoomJoined>(_onRoomJoined);
    on<RoomLeft>(_onRoomLeft);
    on<CreateRoomEvent>(_onCreateRoom);
    on<CreateTutorProfileEvent>(_onCreateTutorProfile);
    on<JoinRoomEvent>(_onJoinRoom);
  }

  Future<void> _onLoadSpeakData(LoadSpeakData event, Emitter<SpeakState> emit) async {
    emit(state.copyWith(status: SpeakStatus.loading));
    try {
      final List<ChatRoom> fetchedRooms = await _speakService.getPublicRooms();
      
      // TEST: Injecting dummy members (13 members) to verify your "Others" UI logic
      _masterRooms = fetchedRooms.map((room) {
        return room.copyWith(
          memberCount: 13,
          members: _generateDummyMembers(13, room.hostId, room.hostName ?? "Host"),
        );
      }).toList();

      _masterTutors = []; // Load real tutors from service when ready

      emit(state.copyWith(
        status: SpeakStatus.success,
        rooms: List.from(_masterRooms),
        tutors: List.from(_masterTutors),
      ));
    } catch (e) {
      emit(state.copyWith(status: SpeakStatus.failure));
    }
  }

  void _onFilterSpeakList(FilterSpeakList event, Emitter<SpeakState> emit) {
    final query = event.query?.toLowerCase() ?? "";
    final category = event.category;

    // Filter Rooms
    final filteredRooms = _masterRooms.where((room) {
      if (category == 'Language Level') return room.level.contains(event.query!);
      if (category == 'Paid') return event.query == 'Free' ? !room.isPaid : room.isPaid;
      
      // General Search: Host Name, Title, or Language
      return room.title.toLowerCase().contains(query) || 
             (room.hostName ?? "").toLowerCase().contains(query) ||
             room.language.toLowerCase().contains(query);
    }).toList();

    // Filter Tutors
    final filteredTutors = _masterTutors.where((tutor) {
      if (category == 'Specialty') return true; // Add specialty field to model if needed
      
      return tutor.name.toLowerCase().contains(query) || 
             tutor.language.toLowerCase().contains(query) ||
             tutor.pricePerHour.toString().contains(query);
    }).toList();

    emit(state.copyWith(
      rooms: filteredRooms,
      tutors: filteredTutors,
      searchQuery: event.query,
      activeCategory: event.category,
    ));
  }

  void _onClearAllFilters(ClearAllFilters event, Emitter<SpeakState> emit) {
    emit(state.copyWith(
      rooms: List.from(_masterRooms),
      tutors: List.from(_masterTutors),
      clearFilters: true,
    ));
  }

  void _onJoinRoom(JoinRoomEvent event, Emitter<SpeakState> emit) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final newMember = RoomMember(
      uid: user.uid,
      displayName: user.displayName,
      avatarUrl: user.photoURL,
      joinedAt: DateTime.now(),
      isHost: false,
    );

    // Update master list optimistically
    _masterRooms = _masterRooms.map((room) {
      if (room.id == event.room.id) {
        if (room.members.any((m) => m.uid == user.uid)) return room;
        return room.copyWith(
          members: List<RoomMember>.from(room.members)..add(newMember),
          memberCount: room.memberCount + 1,
        );
      }
      return room;
    }).toList();

    emit(state.copyWith(rooms: List.from(_masterRooms)));
  }

  Future<void> _onCreateRoom(CreateRoomEvent event, Emitter<SpeakState> emit) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final newRoom = ChatRoom(
      id: _uuid.v4(),
      hostId: user.uid,
      title: event.topic,
      language: event.language,
      level: event.level,
      memberCount: 1,
      maxMembers: event.maxMembers,
      isPaid: event.isPaid,
      hostName: user.displayName ?? "Anonymous",
      hostAvatarUrl: user.photoURL,
      members: [RoomMember(uid: user.uid, displayName: user.displayName, avatarUrl: user.photoURL, joinedAt: DateTime.now(), isHost: true)],
      createdAt: DateTime.now(),
    );

    try {
      await _speakService.createRoom(newRoom);
      _masterRooms.insert(0, newRoom);
      emit(state.copyWith(rooms: List.from(_masterRooms)));
    } catch (e) {
      print("Creation Error: $e");
    }
  }

  void _onChangeSpeakTab(ChangeSpeakTab event, Emitter<SpeakState> emit) {
    final newTab = event.tabIndex == 0 ? SpeakTab.all : (event.tabIndex == 1 ? SpeakTab.tutors : SpeakTab.rooms);
    emit(state.copyWith(currentTab: newTab));
  }

  void _onRoomJoined(RoomJoined event, Emitter<SpeakState> emit) => emit(state.copyWith(activeRoom: event.room));
  void _onRoomLeft(RoomLeft event, Emitter<SpeakState> emit) => emit(state.copyWith(clearActiveRoom: true));

  void _onCreateTutorProfile(CreateTutorProfileEvent event, Emitter<SpeakState> emit) {
    final newTutor = Tutor(id: _uuid.v4(), name: event.name, language: event.language, rating: 0.0, reviews: 0, pricePerHour: event.pricePerHour, imageUrl: event.imageUrl);
    _masterTutors.insert(0, newTutor);
    emit(state.copyWith(tutors: List.from(_masterTutors)));
  }

  List<RoomMember> _generateDummyMembers(int count, String hostId, String hostName) {
    return List.generate(count, (index) {
      bool isHost = index == 0;
      return RoomMember(
        uid: isHost ? hostId : 'user_$index',
        displayName: isHost ? hostName : 'Member $index',
        avatarUrl: 'https://i.pravatar.cc/150?u=${isHost ? hostId : index}',
        joinedAt: DateTime.now(),
        isHost: isHost,
      );
    });
  }
}