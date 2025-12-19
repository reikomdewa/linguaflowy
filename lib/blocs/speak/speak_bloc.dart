import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/models/speak/room_member.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'speak_event.dart';
import 'speak_state.dart';
import '../../models/speak/speak_models.dart';
import '../../services/speak/speak_service.dart';

class SpeakBloc extends Bloc<SpeakEvent, SpeakState> {
  final _uuid = const Uuid();
  final SpeakService _speakService = SpeakService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Master lists holding the true data from the database
  List<ChatRoom> _masterRooms = [];
  List<Tutor> _masterTutors = [];

  SpeakBloc() : super(const SpeakState()) {
    // Basic UI and Loading
    on<LoadSpeakData>(_onLoadSpeakData);
    on<ChangeSpeakTab>(_onChangeSpeakTab);
    on<FilterSpeakList>(_onFilterSpeakList);
    on<ClearAllFilters>(_onClearAllFilters);

    // Media and LiveKit Connection
    on<RoomJoined>(_onRoomJoined);
    on<LeaveRoomEvent>(_onRoomLeft);

    // Room Management
    on<CreateRoomEvent>(_onCreateRoom);
    on<JoinRoomEvent>(_onJoinRoom);
    on<DeleteRoomEvent>(_onDeleteRoom);

    // Tutor Management
    on<CreateTutorProfileEvent>(_onCreateTutorProfile);
    on<DeleteTutorProfileEvent>(_onDeleteTutorProfile);
  }

  // =========================================================
  // THE MASTER FILTER ENGINE
  // =========================================================
  /// This private method is the "Brain" of the Bloc. Every action 
  /// (creation, deletion, filtering) calls this to update the UI 
  /// state instantly based on the current Master lists.
  void _applyFiltersAndEmit(Emitter<SpeakState> emit, {Map<String, String>? newFilters, String? newSearchQuery}) {
    final filters = newFilters ?? state.filters;
    final searchStr = (newSearchQuery ?? state.searchQuery ?? "").toLowerCase();
    final currentUser = _auth.currentUser;

    // 1. Filter Rooms Logic
    final filteredRooms = _masterRooms.where((room) {
      bool matches = true;
      if (filters.containsKey('Language Level')) {
        matches = matches && room.level == filters['Language Level'];
      }
      if (filters.containsKey('Paid')) {
        matches = matches && (filters['Paid'] == 'Free' ? !room.isPaid : room.isPaid);
      }
      if (searchStr.isNotEmpty) {
        matches = matches && (
          room.title.toLowerCase().contains(searchStr) || 
          (room.hostName?.toLowerCase().contains(searchStr) ?? false)
        );
      }
      return matches;
    }).toList();

    // 2. Filter Tutors Logic
    final filteredTutors = _masterTutors.where((tutor) {
      // Force Override: Always show "My Profile" to the user even if filters don't match
      if (currentUser != null && tutor.userId == currentUser.uid) return true;

      bool matches = true;
      if (filters.containsKey('Language Level')) {
        matches = matches && tutor.level == filters['Language Level'];
      }
      if (filters.containsKey('Specialty')) {
        matches = matches && tutor.specialties.contains(filters['Specialty']);
      }
      if (searchStr.isNotEmpty) {
        matches = matches && tutor.name.toLowerCase().contains(searchStr);
      }
      return matches;
    }).toList();

    // 3. Emit brand new list instances to ensure Flutter detects changes
    emit(state.copyWith(
      status: SpeakStatus.success,
      rooms: List.from(filteredRooms),
      tutors: List.from(filteredTutors),
      filters: filters,
      searchQuery: newSearchQuery ?? state.searchQuery,
    ));
  }

  // =========================================================
  // DATA LOADING
  // =========================================================

  Future<void> _onLoadSpeakData(LoadSpeakData event, Emitter<SpeakState> emit) async {
    // Show loading only on first load or manual refresh
    if (_masterRooms.isEmpty && _masterTutors.isEmpty) {
      emit(state.copyWith(status: SpeakStatus.loading));
    }

    try {
      // Parallel fetch for speed
      final results = await Future.wait([
        _speakService.getPublicRooms(),
        _speakService.getTutors(),
      ]);

      _masterRooms = results[0] as List<ChatRoom>;
      _masterTutors = results[1] as List<Tutor>;

      _applyFiltersAndEmit(emit);
    } catch (e) {
      print("Load Data Error: $e");
      emit(state.copyWith(status: SpeakStatus.failure));
    }
  }

  // =========================================================
  // ROOM HANDLERS
  // =========================================================

  Future<void> _onCreateRoom(CreateRoomEvent event, Emitter<SpeakState> emit) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final newRoom = ChatRoom(
      id: _uuid.v4(),
      hostId: user.uid,
      title: event.topic,
      description: event.description ?? "",
      language: event.language,
      level: event.level,
      memberCount: 1,
      maxMembers: event.maxMembers,
      isPaid: event.isPaid,
      hostName: user.displayName,
      hostAvatarUrl: user.photoURL,
      members: [
        RoomMember(
          uid: user.uid, 
          displayName: user.displayName, 
          avatarUrl: user.photoURL, 
          joinedAt: DateTime.now(), 
          isHost: true
        )
      ],
      createdAt: DateTime.now(),
      roomType: event.roomType,
      tags: event.tags,
    );

    // Optimistic UI update
    _masterRooms.insert(0, newRoom);
    _applyFiltersAndEmit(emit);

    // Persist to DB in background
    _speakService.createRoom(newRoom).catchError((e) => print("Firebase Room Error: $e"));
  }

  Future<void> _onJoinRoom(JoinRoomEvent event, Emitter<SpeakState> emit) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      ChatRoom? updatedRoom;
      _masterRooms = _masterRooms.map((room) {
        if (room.id == event.room.id) {
          // Check if already in the room
          if (room.members.any((m) => m.uid == user.uid)) return room;

          updatedRoom = room.copyWith(
            members: List<RoomMember>.from(room.members)
              ..add(RoomMember(
                uid: user.uid,
                displayName: user.displayName,
                avatarUrl: user.photoURL,
                joinedAt: DateTime.now(),
              )),
            memberCount: room.memberCount + 1,
          );
          return updatedRoom!;
        }
        return room;
      }).toList();

      if (updatedRoom != null) {
        _applyFiltersAndEmit(emit);
        // Persist join status to database
        await _speakService.updateRoomMembers(
          updatedRoom!.id, 
          updatedRoom!.members, 
          updatedRoom!.memberCount
        );
      }
    } catch (e) {
      print("Join Room Error: $e");
    }
  }

  Future<void> _onDeleteRoom(DeleteRoomEvent event, Emitter<SpeakState> emit) async {
    // Optimistic UI removal
    _masterRooms.removeWhere((r) => r.id == event.roomId);
    _applyFiltersAndEmit(emit);

    // Background deletion
    try {
      await _speakService.deleteRoom(event.roomId);
    } catch (e) {
      print("Delete Room Error: $e");
    }
  }

  // =========================================================
  // TUTOR HANDLERS
  // =========================================================

  Future<void> _onCreateTutorProfile(CreateTutorProfileEvent event, Emitter<SpeakState> emit) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final newTutor = Tutor(
      id: user.uid, // Use UID to prevent duplicate profiles
      userId: user.uid,
      name: event.name,
      imageUrl: event.imageUrl,
      description: event.description,
      countryOfBirth: event.countryOfBirth,
      isNative: event.isNative,
      language: event.language,
      level: event.level,
      specialties: event.specialties,
      otherLanguages: event.otherLanguages,
      pricePerHour: event.pricePerHour,
      availability: event.availability,
      lessons: event.lessons,
      metadata: event.metadata,
      createdAt: DateTime.now(),
      lastUpdatedAt: DateTime.now(),
      isOnline: true,
      rating: 5.0,
      reviews: 0,
    );

    // Optimistic Update: Replace if exists, else insert
    final index = _masterTutors.indexWhere((t) => t.userId == user.uid);
    if (index != -1) {
      _masterTutors[index] = newTutor;
    } else {
      _masterTutors.insert(0, newTutor);
    }

    _applyFiltersAndEmit(emit);

    // Save to Firestore
    _speakService.createTutorProfile(newTutor).catchError((e) => print("Firebase Tutor Error: $e"));
  }

  Future<void> _onDeleteTutorProfile(DeleteTutorProfileEvent event, Emitter<SpeakState> emit) async {
    _masterTutors.removeWhere((t) => t.id == event.tutorId);
    _applyFiltersAndEmit(emit);

    try {
      await _speakService.deleteTutorProfile(event.tutorId);
    } catch (e) {
      print("Delete Tutor Error: $e");
    }
  }

  // =========================================================
  // UTILITY & STATE HANDLERS
  // =========================================================

  void _onFilterSpeakList(FilterSpeakList event, Emitter<SpeakState> emit) {
    final Map<String, String> updatedFilters = Map.from(state.filters);
    
    if (event.category != null) {
      if (event.query != null) {
        updatedFilters[event.category!] = event.query!;
      } else {
        updatedFilters.remove(event.category);
      }
    }
    
    _applyFiltersAndEmit(emit, 
      newFilters: updatedFilters, 
      newSearchQuery: event.category == null ? event.query : state.searchQuery
    );
  }

  void _onClearAllFilters(ClearAllFilters event, Emitter<SpeakState> emit) {
    emit(state.copyWith(resetFilters: true));
    _applyFiltersAndEmit(emit, newFilters: {}, newSearchQuery: "");
  }

  void _onChangeSpeakTab(ChangeSpeakTab event, Emitter<SpeakState> emit) {
    final newTab = event.tabIndex == 0 ? SpeakTab.all : (event.tabIndex == 1 ? SpeakTab.tutors : SpeakTab.rooms);
    emit(state.copyWith(currentTab: newTab));
  }

  void _onRoomJoined(RoomJoined event, Emitter<SpeakState> emit) => emit(state.copyWith(activeRoom: event.room));

  void _onRoomLeft(LeaveRoomEvent event, Emitter<SpeakState> emit) => emit(state.copyWith(clearActiveRoom: true));
}