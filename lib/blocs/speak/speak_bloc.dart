import 'package:flutter_bloc/flutter_bloc.dart';
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

  SpeakBloc() : super(const SpeakState()) {
    on<LoadSpeakData>(_onLoadSpeakData);
    on<ChangeSpeakTab>(_onChangeSpeakTab);
    on<FilterSpeakList>(_onFilterSpeakList);
    on<RoomJoined>(_onRoomJoined);
    on<RoomLeft>(_onRoomLeft);
    on<CreateRoomEvent>(_onCreateRoom);
    on<CreateTutorProfileEvent>(_onCreateTutorProfile);
  }

  /// 1. Load Data: Fetches REAL rooms from Firestore
  Future<void> _onLoadSpeakData(
    LoadSpeakData event,
    Emitter<SpeakState> emit,
  ) async {
    emit(state.copyWith(status: SpeakStatus.loading));

    try {
      // Fetch public rooms from Firestore
      final List<ChatRoom> realRooms = await _speakService.getPublicRooms();

      // Initialize with empty tutors list (No dummy data)
      // Once you implement TutorService, you would fetch real tutors here.
      final List<Tutor> realTutors = []; 

      emit(state.copyWith(
        status: SpeakStatus.success,
        rooms: realRooms,
        tutors: realTutors,
      ));
    } catch (e) {
      print("Error loading speak data: $e");
      emit(state.copyWith(status: SpeakStatus.failure));
    }
  }

  /// 2. Create Room: Saves to Firestore and Updates State
  Future<void> _onCreateRoom(
    CreateRoomEvent event,
    Emitter<SpeakState> emit,
  ) async {
    final user = _auth.currentUser;

    if (user == null) {
      // In a real app, you might want to emit an error state here
      print("Error: User must be logged in to create a room.");
      return;
    }

    final String roomId = _uuid.v4();
    final String hostName = user.displayName ?? "Anonymous";
    final String? photoUrl = user.photoURL;

    // Create the Model with Real User Data
    final newRoom = ChatRoom(
      id: roomId,
      hostId: user.uid,
      title: event.topic,
      language: event.language,
      level: event.level,
      memberCount: 1, // Starts with the host
      maxMembers: event.maxMembers,
      isPaid: event.isPaid,
      hostName: hostName,
      hostAvatarUrl: photoUrl,
    );

    // Save to Firestore
    try {
      await _speakService.createRoom(newRoom);

      // Optimistic Update: Add to local list immediately so UI feels instant
      final updatedRooms = List<ChatRoom>.from(state.rooms)..insert(0, newRoom);
      emit(state.copyWith(rooms: updatedRooms));
      
    } catch (e) {
      print("Failed to save room to Firestore: $e");
      // Handle error (e.g., show snackbar via listener)
    }
  }

  /// 3. Create Tutor: Local Logic (Update when you have a backend for Tutors)
  void _onCreateTutorProfile(
    CreateTutorProfileEvent event,
    Emitter<SpeakState> emit,
  ) {
    // Currently creates a local object. 
    // To make this permanent, you would need a 'createTutor' method in SpeakService.
    final newTutor = Tutor(
      id: _uuid.v4(),
      name: event.name,
      language: event.language,
      rating: 0.0, 
      reviews: 0,
      pricePerHour: event.pricePerHour,
      imageUrl: event.imageUrl,
    );

    final updatedTutors = List<Tutor>.from(state.tutors)..insert(0, newTutor);
    emit(state.copyWith(tutors: updatedTutors));
  }

  /// 4. Tab Switching Logic
  void _onChangeSpeakTab(
    ChangeSpeakTab event,
    Emitter<SpeakState> emit,
  ) {
    SpeakTab newTab;
    switch (event.tabIndex) {
      case 0:
        newTab = SpeakTab.all;
        break;
      case 1:
        newTab = SpeakTab.tutors;
        break;
      case 2:
        newTab = SpeakTab.rooms;
        break;
      default:
        newTab = SpeakTab.all;
    }
    emit(state.copyWith(currentTab: newTab));
  }

  /// 5. Filter Logic
  void _onFilterSpeakList(
    FilterSpeakList event,
    Emitter<SpeakState> emit,
  ) {
    emit(state.copyWith(selectedLanguage: event.language));
  }

  /// 6. LiveKit Room Joined
  void _onRoomJoined(
    RoomJoined event,
    Emitter<SpeakState> emit,
  ) {
    emit(state.copyWith(activeRoom: event.room));
  }

  /// 7. LiveKit Room Left
  void _onRoomLeft(
    RoomLeft event,
    Emitter<SpeakState> emit,
  ) {
    emit(state.copyWith(clearActiveRoom: true));
  }
}