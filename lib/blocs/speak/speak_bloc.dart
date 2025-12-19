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

  SpeakBloc() : super(const SpeakState()) {
    on<LoadSpeakData>(_onLoadSpeakData);
    on<ChangeSpeakTab>(_onChangeSpeakTab);
    on<FilterSpeakList>(_onFilterSpeakList);
    on<RoomJoined>(_onRoomJoined);
    on<RoomLeft>(_onRoomLeft);
    on<CreateRoomEvent>(_onCreateRoom);
    on<CreateTutorProfileEvent>(_onCreateTutorProfile);

    // Add this handler if you want the UI to update immediately when joining
    on<JoinRoomEvent>(_onJoinRoom);
  }

  /// 1. Load Data: Fetches REAL rooms from Firestore
  // Future<void> _onLoadSpeakData(
  //   LoadSpeakData event,
  //   Emitter<SpeakState> emit,
  // ) async {
  //   emit(state.copyWith(status: SpeakStatus.loading));

  //   try {
  //     // Fetch public rooms from Firestore
  //     final List<ChatRoom> realRooms = await _speakService.getPublicRooms();
  //     final List<Tutor> realTutors = []; // Fetch from service when ready

  //     emit(
  //       state.copyWith(
  //         status: SpeakStatus.success,
  //         rooms: realRooms,
  //         tutors: realTutors,
  //       ),
  //     );
  //   } catch (e) {
  //     emit(state.copyWith(status: SpeakStatus.failure));
  //   }
  // }

  Future<void> _onLoadSpeakData(
    LoadSpeakData event,
    Emitter<SpeakState> emit,
  ) async {
    emit(state.copyWith(status: SpeakStatus.loading));

    try {
      final List<ChatRoom> fetchedRooms = await _speakService.getPublicRooms();

      // --- TEST DATA INJECTION START ---
      final List<ChatRoom> roomsWithDummyData = fetchedRooms.map((room) {
        // Let's test with 12 members to trigger the "+2 others" logic
        int testMemberCount = 20;

        return room.copyWith(
          memberCount: testMemberCount,
          members: _generateDummyMembers(
            testMemberCount,
            room.hostId,
            room.hostName ?? "Host",
          ),
        );
      }).toList();
      // --- TEST DATA INJECTION END ---

      emit(
        state.copyWith(
          status: SpeakStatus.success,
          rooms: roomsWithDummyData, // Use the modified list
          tutors: [],
        ),
      );
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
    if (user == null) return;

    final String roomId = _uuid.v4();
    final String hostName = user.displayName ?? "Anonymous";
    final String? photoUrl = user.photoURL;

    // Create the Member object for the Host
    final hostMember = RoomMember(
      uid: user.uid,
      displayName: hostName,
      avatarUrl: photoUrl,
      joinedAt: DateTime.now(),
      isHost: true, // Mark as host
    );

    // Create the ChatRoom Model
    final newRoom = ChatRoom(
      id: roomId,
      hostId: user.uid,
      title: event.topic,
      language: event.language,
      level: event.level,
      memberCount: 1,
      maxMembers: event.maxMembers,
      isPaid: event.isPaid,
      hostName: hostName,
      hostAvatarUrl: photoUrl,
      members: [hostMember], // Initialize with host
      createdAt: DateTime.now(),
    );

    try {
      await _speakService.createRoom(newRoom);

      // Optimistic Update: Add to local list
      final updatedRooms = List<ChatRoom>.from(state.rooms)..insert(0, newRoom);
      emit(state.copyWith(rooms: updatedRooms));
    } catch (e) {
      print("Failed to save room: $e");
    }
  }

  /// 3. Join Room: Updates member list so avatars appear in the row
  Future<void> _onJoinRoom(
    JoinRoomEvent event,
    Emitter<SpeakState> emit,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // 1. Create the current user as a RoomMember
    final newMember = RoomMember(
      uid: user.uid,
      displayName: user.displayName ?? "User",
      avatarUrl: user.photoURL,
      joinedAt: DateTime.now(),
      isHost: false,
    );

    // 2. Find the room in the current state and update it
    final updatedRooms = state.rooms.map((room) {
      if (room.id == event.room.id) {
        // Check if already a member to prevent duplicates
        final alreadyMember = room.members.any((m) => m.uid == user.uid);
        if (alreadyMember) return room;

        // Add new member and increment count
        final updatedMemberList = List<RoomMember>.from(room.members)
          ..add(newMember);
        return room.copyWith(
          members: updatedMemberList,
          memberCount: room.memberCount + 1,
        );
      }
      return room;
    }).toList();

    emit(state.copyWith(rooms: updatedRooms));

    // 3. Inform service/backend (Firestore update)
    // await _speakService.addUserToRoom(event.room.id, newMember);
  }

  /// 4. Create Tutor: Local Logic
  void _onCreateTutorProfile(
    CreateTutorProfileEvent event,
    Emitter<SpeakState> emit,
  ) {
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

  /// 5. Tab Switching Logic
  void _onChangeSpeakTab(ChangeSpeakTab event, Emitter<SpeakState> emit) {
    final tabIndex = event.tabIndex;
    final newTab = tabIndex == 0
        ? SpeakTab.all
        : (tabIndex == 1 ? SpeakTab.tutors : SpeakTab.rooms);
    emit(state.copyWith(currentTab: newTab));
  }

  /// 6. Filter Logic
  void _onFilterSpeakList(FilterSpeakList event, Emitter<SpeakState> emit) {
    emit(state.copyWith(selectedLanguage: event.language));
  }

  /// 7. LiveKit Room Joined
  void _onRoomJoined(RoomJoined event, Emitter<SpeakState> emit) {
    emit(state.copyWith(activeRoom: event.room));
  }

  /// 8. LiveKit Room Left
  void _onRoomLeft(RoomLeft event, Emitter<SpeakState> emit) {
    emit(state.copyWith(clearActiveRoom: true));
  }

  List<RoomMember> _generateDummyMembers(
    int count,
    String hostId,
    String hostName,
  ) {
    return List.generate(count, (index) {
      if (index == 0) {
        // Always include the host as the first member for testing
        return RoomMember(
          uid: hostId,
          displayName: hostName,
          avatarUrl: 'https://i.pravatar.cc/150?u=$hostId',
          joinedAt: DateTime.now(),
          isHost: true,
        );
      }
      return RoomMember(
        uid: 'user_$index',
        displayName: 'Member $index',
        // Random avatar URL from pravatar
        avatarUrl: 'https://i.pravatar.cc/150?u=user_$index',
        joinedAt: DateTime.now(),
        isHost: false,
      );
    });
  }
}
