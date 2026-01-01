import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:linguaflow/models/speak/room_member.dart';
import 'package:linguaflow/models/speak/speak_models.dart';
import 'package:linguaflow/services/speak/speak_service.dart';
import 'package:uuid/uuid.dart';

// Imports from your project structure
import 'room_event.dart';
import 'room_state.dart';

class RoomBloc extends Bloc<RoomEvent, RoomState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SpeakService _speakService = SpeakService();
  final _uuid = const Uuid();

  StreamSubscription? _roomsSubscription;

  RoomBloc() : super(const RoomState()) {
    // Data & Filtering
    on<LoadRooms>(_onLoadRooms);
    on<RoomsUpdated>(_onRoomsUpdated);
    on<FilterRooms>(_onFilterRooms);
    on<ClearRoomFilters>(_onClearRoomFilters);

    // CRUD
    on<CreateRoomEvent>(_onCreateRoom);
    on<DeleteRoomEvent>(_onDeleteRoom);

    // LiveKit & Interaction
    on<JoinRoomEvent>(_onJoinRoom);
    on<RoomJoined>(
      (event, emit) => emit(state.copyWith(activeLivekitRoom: event.room)),
    );
    on<LeaveRoomEvent>(_onLeaveRoom);

    // Moderation
    on<ToggleSpotlightEvent>(_onToggleSpotlight);
    on<KickUserEvent>(_onKickUser);
  }

  @override
  Future<void> close() {
    _roomsSubscription?.cancel();
    return super.close();
  }

  // =========================================================
  // 1. REAL-TIME LOADING
  // =========================================================
  void _onLoadRooms(LoadRooms event, Emitter<RoomState> emit) {
    emit(state.copyWith(status: RoomStatus.loading));

    _roomsSubscription?.cancel();
    _roomsSubscription = _firestore
        .collection('rooms')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
          final List<ChatRoom> liveRooms = snapshot.docs.map((doc) {
            // Uses the factory method from your updated ChatRoom model
            return ChatRoom.fromMap(doc.data(), doc.id);
          }).toList();

          add(RoomsUpdated(liveRooms));
        });
  }

  void _onRoomsUpdated(RoomsUpdated event, Emitter<RoomState> emit) {
    // Update the master list, then re-apply filters
    _applyFilters(emit, allRooms: event.rooms);
  }

  // =========================================================
  // 2. FILTERING ENGINE (Includes Ghost Room Logic)
  // =========================================================
  void _onFilterRooms(FilterRooms event, Emitter<RoomState> emit) {
    final Map<String, String> updatedFilters = Map.from(state.filters);

    if (event.category != null) {
      if (event.query != null) {
        updatedFilters[event.category!] = event.query!;
      } else {
        updatedFilters.remove(event.category);
      }
    }

    _applyFilters(
      emit,
      filters: updatedFilters,
      query: event.category == null ? event.query : state.searchQuery,
    );
  }

  void _onClearRoomFilters(ClearRoomFilters event, Emitter<RoomState> emit) {
    emit(state.copyWith(resetFilters: true));
    _applyFilters(emit, filters: {}, query: "");
  }

 void _applyFilters(
    Emitter<RoomState> emit, {
    List<ChatRoom>? allRooms,
    Map<String, String>? filters,
    String? query,
  }) {
    final _all = allRooms ?? state.allRooms;
    final _filters = filters ?? state.filters;
    final _query = (query ?? state.searchQuery).toLowerCase();

    // --- GHOST ROOM LOGIC ---
    // Hide rooms that are empty (0 members) AND older than 5 minutes.
    final DateTime staleCutoff = DateTime.now().subtract(
      const Duration(minutes: 5),
    );

    final _filtered = _all.where((room) {
      // 1. Ghost Check
      if (room.memberCount == 0 && room.createdAt.isBefore(staleCutoff)) {
        return false;
      }

      // 2. [NEW] HIDE TUTOR SESSIONS
      // This ensures the specific room created by the TutorCard 
      // does not appear in the public social feed.
      if (room.isPrivate || room.roomType == 'tutor_session') {
        return false;
      }

      // 3. Search Query
      if (_query.isNotEmpty) {
        final matchesTitle = room.title.toLowerCase().contains(_query);
        final matchesHost =
            room.hostName?.toLowerCase().contains(_query) ?? false;
        if (!matchesTitle && !matchesHost) return false;
      }

      // 4. Category Filters
      if (_filters.containsKey('Language Level')) {
        if (room.level != _filters['Language Level']) return false;
      }
      if (_filters.containsKey('Paid')) {
        final isPaidFilter = _filters['Paid'] != 'Free';
        if (room.isPaid != isPaidFilter) return false;
      }

      return true;
    }).toList();

    emit(
      state.copyWith(
        status: RoomStatus.success,
        allRooms: _all,
        filteredRooms: _filtered,
        filters: _filters,
        searchQuery: query,
      ),
    );
  }

  

  Future<void> _onDeleteRoom(
    DeleteRoomEvent event,
    Emitter<RoomState> emit,
  ) async {
    // Optimistic Remove
    final updatedList = state.allRooms
        .where((r) => r.id != event.roomId)
        .toList();
    _applyFilters(emit, allRooms: updatedList);

    await _speakService.deleteRoom(event.roomId);
  }
// =========================================================
  // FIX 1: CREATE ROOM (With XP Fetching)
  // =========================================================
  Future<void> _onCreateRoom(
    CreateRoomEvent event,
    Emitter<RoomState> emit,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // 1. Fetch Host's XP from 'users' collection
    int userXp = 0;
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        userXp = (userDoc.data()?['xp'] as num?)?.toInt() ?? 0;
      }
    } catch (e) {
      print("⚠️ [RoomBloc] Could not fetch host XP: $e");
    }

    final newRoom = ChatRoom(
      id: _uuid.v4(),
      hostId: user.uid,
      title: event.topic,
      description: event.description,
      language: event.language,
      level: event.level,
      memberCount: 1,
      maxMembers: event.maxMembers,
      isPaid: event.isPaid,
      password: event.password,
      hostName: user.displayName,
      hostAvatarUrl: user.photoURL,
      members: [
        RoomMember(
          uid: user.uid,
          displayName: user.displayName,
          avatarUrl: user.photoURL,
          joinedAt: DateTime.now(),
          isHost: true,
          xp: userXp, // <--- Pass the fetched XP here
        ),
      ],
      createdAt: DateTime.now(),
      // Auto-expire in 24h for Firebase Policy
      expireAt: DateTime.now().add(const Duration(hours: 24)),
      roomType: event.roomType,
      tags: event.tags,
    );

    // Optimistic Update
    final updatedList = List<ChatRoom>.from(state.allRooms)..insert(0, newRoom);
    _applyFilters(emit, allRooms: updatedList);

    try {
      await _speakService.createRoom(newRoom);
    } catch (e) {
      print("Error creating room: $e");
    }
  }

  // (Delete room logic remains the same...)

  // =========================================================
  // FIX 2: JOIN ROOM (With XP Fetching & Robust Parsing)
  // =========================================================
  Future<void> _onJoinRoom(JoinRoomEvent event, Emitter<RoomState> emit) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // We set this immediately so UI can show "Connecting..."
    emit(state.copyWith(activeChatRoom: event.room));

    // 1. Fetch Guest's XP from 'users' collection
    int userXp = 0;
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        userXp = (userDoc.data()?['xp'] as num?)?.toInt() ?? 0;
      }
    } catch (e) {
      print("⚠️ [RoomBloc] Could not fetch guest XP: $e");
    }

    try {
      final roomRef = _firestore.collection('rooms').doc(event.room.id);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;

        final currentData = snapshot.data()!;
        
        // 2. Robust List Parsing (Safe against nulls or wrong types)
        final rawList = currentData['members'] as List<dynamic>? ?? [];
        
        final members = rawList.map((m) {
           if (m is Map<String, dynamic>) return RoomMember.fromMap(m);
           if (m is Map) return RoomMember.fromMap(Map<String, dynamic>.from(m));
           return null;
        }).where((m) => m != null).cast<RoomMember>().toList();

        // 3. Add user if not present
        if (!members.any((m) => m.uid == user.uid)) {
          members.add(
            RoomMember(
              uid: user.uid,
              displayName: user.displayName ?? "Guest",
              avatarUrl: user.photoURL,
              joinedAt: DateTime.now(),
              isHost: false,
              xp: userXp, // <--- Pass the fetched XP here
            ),
          );

          // 4. Update Firestore
          transaction.update(roomRef, {
            'members': members.map((m) => m.toMap()).toList(),
            'memberCount': members.length,
            'lastUpdatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      print("Join Error: $e");
    }
  }

  Future<void> _onLeaveRoom(
    LeaveRoomEvent event,
    Emitter<RoomState> emit,
  ) async {
    // Clear the active room state
    emit(
      state.copyWith(clearActiveChatRoom: true, clearActiveLivekitRoom: true),
    );
    // Note: The actual Firestore member removal happens in SpeakService or via Webhook
  }

  // =========================================================
  // 5. MODERATION
  // =========================================================
  Future<void> _onToggleSpotlight(
    ToggleSpotlightEvent event,
    Emitter<RoomState> emit,
  ) async {
    await _firestore.collection('rooms').doc(event.roomId).update({
      'spotlightedUserId': event.userId,
    });
  }

  Future<void> _onKickUser(KickUserEvent event, Emitter<RoomState> emit) async {
    try {
      final roomRef = _firestore.collection('rooms').doc(event.roomId);
      final snapshot = await roomRef.get();
      if (!snapshot.exists) return;

      final members = List<Map<String, dynamic>>.from(
        snapshot.data()?['members'] ?? [],
      );

      members.removeWhere((m) {
        return m['uid'] == event.userId || m['displayName'] == event.userId;
      });

      await roomRef.update({'members': members, 'memberCount': members.length});
    } catch (e) {
      print("Kick Error: $e");
    }
  }
}
