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

  // Master lists to hold original data from Firebase
  List<ChatRoom> _masterRooms = [];
  List<Tutor> _masterTutors = [];

  SpeakBloc() : super(const SpeakState()) {
    on<LoadSpeakData>(_onLoadSpeakData);
    on<ChangeSpeakTab>(_onChangeSpeakTab);
    on<FilterSpeakList>(_onFilterSpeakList);
    on<ClearAllFilters>(_onClearAllFilters);
    on<RoomJoined>(_onRoomJoined);
    on<LeaveRoomEvent>(_onRoomLeft);
    on<CreateRoomEvent>(_onCreateRoom);
    on<CreateTutorProfileEvent>(_onCreateTutorProfile);
    on<JoinRoomEvent>(_onJoinRoom);
    on<DeleteTutorProfileEvent>(_onDeleteTutorProfile);
on<DeleteRoomEvent>(_onDeleteRoom);
  }

  Future<void> _onDeleteTutorProfile(DeleteTutorProfileEvent event, Emitter<SpeakState> emit) async {
  try {
    await _speakService.deleteTutorProfile(event.tutorId);
    // Remove from local master list
    _masterTutors.removeWhere((t) => t.id == event.tutorId);
    // Emit new state to trigger UI update
    emit(state.copyWith(tutors: List.from(_masterTutors)));
  } catch (e) {
    print("Delete Tutor Error: $e");
  }
}

Future<void> _onDeleteRoom(DeleteRoomEvent event, Emitter<SpeakState> emit) async {
  try {
    await _speakService.deleteRoom(event.roomId);
    // Remove from local master list
    _masterRooms.removeWhere((r) => r.id == event.roomId);
    // Emit new state to trigger UI update
    emit(state.copyWith(rooms: List.from(_masterRooms)));
  } catch (e) {
    print("Delete Room Error: $e");
  }
}

  Future<void> _onLoadSpeakData(LoadSpeakData event, Emitter<SpeakState> emit) async {
  // 1. SILENT LOADING: If we already have data, don't show the full-screen spinner.
  // Only show the spinner if the lists are currently empty.
  if (_masterRooms.isEmpty && _masterTutors.isEmpty) {
    emit(state.copyWith(status: SpeakStatus.loading));
  }

  try {
    // 2. PARALLEL FETCHING: Fetch both at the same time instead of one after another.
    // This cut the wait time in half.
    final results = await Future.wait([
      _speakService.getPublicRooms(),
      _speakService.getTutors(), // Ensure this method exists in your SpeakService
    ]);

    final List<ChatRoom> fetchedRooms = results[0] as List<ChatRoom>;
    final List<Tutor> fetchedTutors = results[1] as List<Tutor>;

    _masterRooms = fetchedRooms;
    _masterTutors = fetchedTutors;

    emit(state.copyWith(
      status: SpeakStatus.success,
      rooms: _masterRooms,
      tutors: _masterTutors,
    ));
  } catch (e) {
    // If it fails but we have old data, stay in success but maybe show a snackbar
    if (_masterRooms.isNotEmpty) {
      emit(state.copyWith(status: SpeakStatus.success));
    } else {
      emit(state.copyWith(status: SpeakStatus.failure));
    }
  }
}

  void _onFilterSpeakList(FilterSpeakList event, Emitter<SpeakState> emit) {
    // 1. Update the filters map locally
    final Map<String, String> updatedFilters = Map.from(state.filters);
    
    if (event.category != null) {
      if (event.query != null) {
        updatedFilters[event.category!] = event.query!;
      } else {
        updatedFilters.remove(event.category); // Reset category if query is null
      }
    }

    final String searchStr = (event.category == null ? event.query : state.searchQuery)?.toLowerCase() ?? "";

    // 2. Filter Rooms Logic
    final filteredRooms = _masterRooms.where((room) {
      bool matches = true;
      
      // Filter by Language Level
      if (updatedFilters.containsKey('Language Level')) {
        matches = matches && room.level == updatedFilters['Language Level'];
      }
      // Filter by Paid/Free
      if (updatedFilters.containsKey('Paid')) {
        matches = matches && (updatedFilters['Paid'] == 'Free' ? !room.isPaid : room.isPaid);
      }
      // Filter by Search Title
      if (searchStr.isNotEmpty) {
        matches = matches && room.title.toLowerCase().contains(searchStr);
      }
      
      return matches;
    }).toList();

    // 3. Filter Tutors Logic
    final filteredTutors = _masterTutors.where((tutor) {
      bool matches = true;

      // Filter by Tutor Level (Proficiency)
      if (updatedFilters.containsKey('Language Level')) {
        matches = matches && tutor.level == updatedFilters['Language Level'];
      }
      // Filter by Specialty
      if (updatedFilters.containsKey('Specialty')) {
        matches = matches && tutor.specialties.contains(updatedFilters['Specialty']);
      }
      // Filter by Search Name
      if (searchStr.isNotEmpty) {
        matches = matches && tutor.name.toLowerCase().contains(searchStr);
      }

      return matches;
    }).toList();

    emit(state.copyWith(
      rooms: filteredRooms,
      tutors: filteredTutors,
      filters: updatedFilters,
      searchQuery: event.category == null ? event.query : state.searchQuery,
    ));
  }

  void _onClearAllFilters(ClearAllFilters event, Emitter<SpeakState> emit) {
    emit(state.copyWith(
      rooms: _masterRooms, 
      tutors: _masterTutors, 
      resetFilters: true,
    ));
  }

  void _onChangeSpeakTab(ChangeSpeakTab event, Emitter<SpeakState> emit) {
    final newTab = event.tabIndex == 0 
        ? SpeakTab.all 
        : (event.tabIndex == 1 ? SpeakTab.tutors : SpeakTab.rooms);
    emit(state.copyWith(currentTab: newTab));
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
      hostName: user.displayName,
      hostAvatarUrl: user.photoURL,
      members: [
        RoomMember(
          uid: user.uid, 
          displayName: user.displayName, 
          avatarUrl: user.photoURL, 
          joinedAt: DateTime.now(), 
          isHost: true,
        )
      ],
      createdAt: DateTime.now(),
    );

    _masterRooms.insert(0, newRoom);
    
    // Re-apply current filters to the new list
  
      add(FilterSpeakList(state.searchQuery)); 
  }

  // Inside SpeakBloc
Future<void> _onCreateTutorProfile(
  CreateTutorProfileEvent event, 
  Emitter<SpeakState> emit
) async {
  // 1. Get the current user to use their UID as the Tutor ID
  final user = _auth.currentUser;
  if (user == null) {
    print("Error: User must be logged in to create a profile");
    return;
  }

  // 2. Construct the robust Tutor model using the Event data
  final newTutor = Tutor(
    id: user.uid, 
    userId: user.uid, // Using UID instead of random UUID for better indexing
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
    
    // Default values for a brand new profile
    rating: 0.0,
    reviews: 0,
    totalHoursTaught: 0,
    totalStudents: 0,
    isVerified: false,
    isSuperTutor: false,
    isOnline: true, // Assuming they are online since they just created it
    profileCompletion: 0.8, // Basic info is there
    createdAt: DateTime.now(),
    lastUpdatedAt: DateTime.now(),
  );

  try {
    // 3. Persist to Firestore via the SpeakService
    await _speakService.createTutorProfile(newTutor);

    // 4. Update the Master list (memory)
    // We check if the tutor already exists in the list to prevent duplicates
    final index = _masterTutors.indexWhere((t) => t.id == newTutor.id);
    if (index != -1) {
      _masterTutors[index] = newTutor; // Update existing
    } else {
      _masterTutors.insert(0, newTutor); // Add new
    }
    
    // 5. Update UI State
    // We emit a success status and the updated list
    emit(state.copyWith(
      status: SpeakStatus.success,
      tutors: List.from(_masterTutors),
    ));

    print("Tutor profile successfully created for: ${newTutor.name}");
  } catch (e) {
    print("Error saving tutor profile to Firebase: $e");
    emit(state.copyWith(status: SpeakStatus.failure));
  }
}
  void _onJoinRoom(JoinRoomEvent event, Emitter<SpeakState> emit) {
    final user = _auth.currentUser;
    if (user == null) return;

    _masterRooms = _masterRooms.map((room) {
      if (room.id == event.room.id) {
        if (room.members.any((m) => m.uid == user.uid)) return room;
        return room.copyWith(
          members: List<RoomMember>.from(room.members)
            ..add(RoomMember(
              uid: user.uid, 
              displayName: user.displayName, 
              joinedAt: DateTime.now(),
            )),
          memberCount: room.memberCount + 1,
        );
      }
      return room;
    }).toList();

    emit(state.copyWith(rooms: _masterRooms));
  }

  void _onRoomJoined(RoomJoined event, Emitter<SpeakState> emit) => 
      emit(state.copyWith(activeRoom: event.room));

  void _onRoomLeft(LeaveRoomEvent event, Emitter<SpeakState> emit) => 
      emit(state.copyWith(clearActiveRoom: true));

  // Helper for mock UI
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