import 'dart:async';
import 'package:flutter/material.dart';
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
    on<UpdateRoomInfoEvent>(_onUpdateRoomInfo);
    on<UpdateActiveFeatureEvent>(_onUpdateActiveFeature);
    // Moderation
    on<ToggleSpotlightEvent>(_onToggleSpotlight);
    on<ToggleRoomLockEvent>(_onToggleRoomLock);
    on<ReportRoomEvent>(_onReportRoom);

    on<KickUserEvent>(_onKickUser);

    // ADD THESE TO CONSTRUCTOR
    on<RequestBoardAccessEvent>(_onRequestBoardAccess);
    on<CancelBoardRequestEvent>(_onCancelBoardRequest);
    on<GrantBoardAccessEvent>(_onGrantBoardAccess);
    on<StopBoardSharingEvent>(_onStopBoardSharing);

    on<RequestYouTubeAccessEvent>(_onRequestYouTubeAccess);
    on<CancelYouTubeRequestEvent>(_onCancelYouTubeRequest);
    on<PlayYouTubeVideoEvent>(_onPlayYouTubeVideo);
    on<StopYouTubeEvent>(_onStopYouTube);
    on<SyncYouTubeStateEvent>(_onSyncYouTubeState);

    on<RequestRejoinEvent>(_onRequestRejoin);
    on<ApproveRejoinEvent>(_onApproveRejoin);
    on<DenyRejoinEvent>(_onDenyRejoin);
  }

  @override
  Future<void> close() {
    _roomsSubscription?.cancel();
    return super.close();
  }

  Future<void> _onKickUser(KickUserEvent event, Emitter<RoomState> emit) async {
    print(
      "🔥 BLOC: Attempting to kick user: ${event.userId} from room: ${event.roomId}",
    );

    try {
      final roomRef = _firestore.collection('rooms').doc(event.roomId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) {
          print("❌ BLOC: Room document does not exist!");
          return;
        }

        final data = snapshot.data()!;
        final members = List<Map<String, dynamic>>.from(data['members'] ?? []);

        print("🔍 BLOC: Current members count: ${members.length}");

        // Check if user exists in list before removing
        final initialCount = members.length;
        members.removeWhere((m) => m['uid'] == event.userId);
        final afterCount = members.length;

        if (initialCount == afterCount) {
          print(
            "⚠️ BLOC: User ${event.userId} was NOT found in the 'members' list. IDs might be mismatching.",
          );
          // We continue anyway to ensure they are added to the ban list
        } else {
          print("✅ BLOC: User removed from members list.");
        }

        // Add to ban list logic
        List<String> currentBans = List<String>.from(
          data['bannedUserIds'] ?? [],
        );
        if (!currentBans.contains(event.userId)) {
          currentBans.add(event.userId);
        }

        transaction.update(roomRef, {
          'members': members,
          'memberCount': members.length,
          'bannedUserIds': currentBans,
          'lastUpdatedAt': FieldValue.serverTimestamp(), // Force client update
        });
      });

      print("🚀 BLOC: Kick/Ban transaction completed successfully.");
    } catch (e) {
      print("❌ BLOC: Error kicking user: $e");
    }
  }

  // --- NEW HANDLERS ---

  Future<void> _onRequestRejoin(
    RequestRejoinEvent event,
    Emitter<RoomState> emit,
  ) async {
    try {
      final requestData = {
        'uid': event.userId,
        'displayName': event.displayName,
        'avatarUrl': event.avatarUrl,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _firestore.collection('rooms').doc(event.roomId).update({
        'joinRequests': FieldValue.arrayUnion([requestData]),
      });
    } catch (e) {
      debugPrint("Error requesting rejoin: $e");
    }
  }

  Future<void> _onApproveRejoin(
    ApproveRejoinEvent event,
    Emitter<RoomState> emit,
  ) async {
    try {
      final roomRef = _firestore.collection('rooms').doc(event.roomId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;

        final data = snapshot.data()!;

        // 1. Unban the User
        final bannedUserIds = List<String>.from(data['bannedUserIds'] ?? []);
        bannedUserIds.remove(event.userId);

        // 2. Remove ANY request associated with this User ID
        // (This is safer than arrayRemove because it doesn't require map equality)
        final joinRequests = List<Map<String, dynamic>>.from(
          (data['joinRequests'] as List? ?? []).map(
            (e) => Map<String, dynamic>.from(e),
          ),
        );

        joinRequests.removeWhere((req) => req['uid'] == event.userId);

        // 3. Update
        transaction.update(roomRef, {
          'bannedUserIds': bannedUserIds,
          'joinRequests': joinRequests,
        });
      });
    } catch (e) {
      debugPrint("Error approving rejoin: $e");
    }
  }

  Future<void> _onDenyRejoin(
    DenyRejoinEvent event,
    Emitter<RoomState> emit,
  ) async {
    try {
      final roomRef = _firestore.collection('rooms').doc(event.roomId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;

        final data = snapshot.data()!;

        // Remove the request based on exact object or ID logic
        // We use the ID from the passed map to be safe
        final targetUid = event.requestMap['uid'];

        final joinRequests = List<Map<String, dynamic>>.from(
          (data['joinRequests'] as List? ?? []).map(
            (e) => Map<String, dynamic>.from(e),
          ),
        );

        if (targetUid != null) {
          joinRequests.removeWhere((req) => req['uid'] == targetUid);
        } else {
          // Fallback if UID is missing in map (rare)
          joinRequests.remove(event.requestMap);
        }

        transaction.update(roomRef, {'joinRequests': joinRequests});
      });
    } catch (e) {
      debugPrint("Error denying rejoin: $e");
    }
  }

  Future<void> _onToggleRoomLock(
    ToggleRoomLockEvent event,
    Emitter<RoomState> emit,
  ) async {
    try {
      // We map "Pause" to "isPrivate" (Locking the room so no new users join)
      await _firestore.collection('rooms').doc(event.roomId).update({
        'isPrivate': event.isLocked,
      });
    } catch (e) {
      debugPrint("Error locking room: $e");
    }
  }

  Future<void> _onReportRoom(
    ReportRoomEvent event,
    Emitter<RoomState> emit,
  ) async {
    try {
      await _firestore.collection('reports').add({
        'roomId': event.roomId,
        'reporterId': event.reporterId,
        'reason': event.reason,
        'description': event.description,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      debugPrint("Error reporting room: $e");
    }
  }

  Future<void> _onSyncYouTubeState(
    SyncYouTubeStateEvent event,
    Emitter<RoomState> emit,
  ) async {
    try {
      // We store the state as a Map
      await _firestore.collection('rooms').doc(event.roomId).update({
        'activeFeatureState': {
          'status': event.status,
          'position': event.positionSeconds,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
      });
    } catch (e) {
      debugPrint("Error syncing YouTube state: $e");
    }
  }

  Future<void> _onRequestYouTubeAccess(
    RequestYouTubeAccessEvent event,
    Emitter<RoomState> emit,
  ) async {
    try {
      // Add an object { userId, url } to the array
      final requestObj = {
        'userId': event.userId,
        'url': event.videoUrl,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _firestore.collection('rooms').doc(event.roomId).update({
        'youtubeRequests': FieldValue.arrayUnion([requestObj]),
      });
    } catch (e) {
      debugPrint("Error requesting YouTube: $e");
    }
  }

  Future<void> _onCancelYouTubeRequest(
    CancelYouTubeRequestEvent event,
    Emitter<RoomState> emit,
  ) async {
    try {
      // Remove the specific object
      await _firestore.collection('rooms').doc(event.roomId).update({
        'youtubeRequests': FieldValue.arrayRemove([event.requestMap]),
      });
    } catch (e) {
      debugPrint("Error canceling YouTube request: $e");
    }
  }

  Future<void> _onPlayYouTubeVideo(
    PlayYouTubeVideoEvent event,
    Emitter<RoomState> emit,
  ) async {
    try {
      final Map<String, dynamic> updates = {
        'activeFeature': 'youtube',
        'activeFeatureData': event.videoUrl,

        // --- FIX: RESET THE SYNC STATE ---
        // This prevents the new video from trying to seek to the old video's time
        'activeFeatureState': {
          'status': 'playing',
          'position': 0,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
      };

      if (event.requestToRemove != null) {
        updates['youtubeRequests'] = FieldValue.arrayRemove([
          event.requestToRemove,
        ]);
      }

      await _firestore.collection('rooms').doc(event.roomId).update(updates);
    } catch (e) {
      debugPrint("Error playing YouTube video: $e");
    }
  }

  Future<void> _onStopYouTube(
    StopYouTubeEvent event,
    Emitter<RoomState> emit,
  ) async {
    try {
      await _firestore.collection('rooms').doc(event.roomId).update({
        'activeFeature': 'none',
        'activeFeatureData': null,
      });
    } catch (e) {
      debugPrint("Error stopping YouTube: $e");
    }
  }

  Future<void> _onRequestBoardAccess(
    RequestBoardAccessEvent event,
    Emitter<RoomState> emit,
  ) async {
    try {
      await _firestore.collection('rooms').doc(event.roomId).update({
        'boardRequests': FieldValue.arrayUnion([event.userId]),
      });
    } catch (e) {
      debugPrint("Error requesting board: $e");
    }
  }

  Future<void> _onCancelBoardRequest(
    CancelBoardRequestEvent event,
    Emitter<RoomState> emit,
  ) async {
    try {
      await _firestore.collection('rooms').doc(event.roomId).update({
        'boardRequests': FieldValue.arrayRemove([event.userId]),
      });
    } catch (e) {
      debugPrint("Error canceling board request: $e");
    }
  }

  Future<void> _onGrantBoardAccess(
    GrantBoardAccessEvent event,
    Emitter<RoomState> emit,
  ) async {
    try {
      // 1. Set feature to whiteboard
      // 2. Set data to the User ID who is streaming
      // 3. Clear requests list (optional, or just remove the accepted one)
      await _firestore.collection('rooms').doc(event.roomId).update({
        'activeFeature': 'whiteboard',
        'activeFeatureData': event.targetUserId,
        'boardRequests': FieldValue.arrayRemove([event.targetUserId]),
      });
    } catch (e) {
      debugPrint("Error granting board access: $e");
    }
  }

  Future<void> _onStopBoardSharing(
    StopBoardSharingEvent event,
    Emitter<RoomState> emit,
  ) async {
    try {
      await _firestore.collection('rooms').doc(event.roomId).update({
        'activeFeature': 'none',
        'activeFeatureData': null,
      });
    } catch (e) {
      debugPrint("Error stopping board: $e");
    }
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
    //inactive rooms
    // --- GHOST ROOM LOGIC ---
    // Hide rooms that are empty (0 members) AND older than 10 minutes.
    final DateTime staleCutoff = DateTime.now().subtract(
      const Duration(minutes: 60 * 2),
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

  // In RoomBloc class

  // =========================================================
  // FIX 2: JOIN ROOM (With "Ghost" Cleanup & XP Fetching)
  // =========================================================
  // FIX 2: JOIN ROOM (With Ban Check, Ghost Cleanup & XP)
  // =========================================================
  Future<void> _onJoinRoom(JoinRoomEvent event, Emitter<RoomState> emit) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // We set this immediately so UI can show "Connecting..."
    emit(state.copyWith(activeChatRoom: event.room));

    // --- STEP A: CLEANUP (Remove user from ANY other rooms first) ---
    final roomsWithUser = state.allRooms.where((r) {
      return r.id != event.room.id && r.members.any((m) => m.uid == user.uid);
    }).toList();

    for (final oldRoom in roomsWithUser) {
      print("🧹 [RoomBloc] Removing user from old room: ${oldRoom.title}");
      try {
        await _removeUserFromRoomFirestore(oldRoom.id, user.uid);
      } catch (e) {
        print("⚠️ Failed to clean up old room ${oldRoom.id}: $e");
      }
    }

    // --- STEP B: PREPARE DATA (XP) ---
    int userXp = 0;
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        userXp = (userDoc.data()?['xp'] as num?)?.toInt() ?? 0;
      }
    } catch (e) {
      print("⚠️ [RoomBloc] Could not fetch guest XP: $e");
    }

    // --- STEP C: JOIN NEW ROOM (With Ban Check) ---
    try {
      final roomRef = _firestore.collection('rooms').doc(event.room.id);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) throw Exception("Room does not exist");

        final currentData = snapshot.data()!;

        // 1. SECURITY CHECK: Is user banned?
        // Even if UI checks this, the database must enforce it to prevent forced writes.
        final bannedList = List<String>.from(currentData['bannedUserIds'] ?? []);
        if (bannedList.contains(user.uid)) {
          throw Exception("BANNED_USER"); 
        }

        // 2. Parse Members
        final rawList = currentData['members'] as List<dynamic>? ?? [];
        final members = rawList
            .map((m) {
              if (m is Map<String, dynamic>) return RoomMember.fromMap(m);
              if (m is Map)
                return RoomMember.fromMap(Map<String, dynamic>.from(m));
              return null;
            })
            .where((m) => m != null)
            .cast<RoomMember>()
            .toList();

        // 3. Add user if not present
        if (!members.any((m) => m.uid == user.uid)) {
          members.add(
            RoomMember(
              uid: user.uid, // This ensures Firestore has the correct UID
              displayName: user.displayName ?? "Guest",
              avatarUrl: user.photoURL,
              joinedAt: DateTime.now(),
              isHost: false,
              xp: userXp,
            ),
          );

          transaction.update(roomRef, {
            'members': members.map((m) => m.toMap()).toList(),
            'memberCount': members.length,
            'lastUpdatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      print("Join Error: $e");
      
      // If error was "BANNED_USER", you might want to show a specific state
      // For now, we just clear the active room so the UI knows join failed.
      emit(state.copyWith(clearActiveChatRoom: true));
    }
  }

  /// Helper to remove a user from a specific room ID in Firestore
  Future<void> _removeUserFromRoomFirestore(
    String roomId,
    String userId,
  ) async {
    final roomRef = _firestore.collection('rooms').doc(roomId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(roomRef);
      if (!snapshot.exists) return;

      final currentData = snapshot.data()!;
      final rawList = currentData['members'] as List<dynamic>? ?? [];

      final members = rawList
          .map((m) {
            if (m is Map<String, dynamic>) return RoomMember.fromMap(m);
            if (m is Map)
              return RoomMember.fromMap(Map<String, dynamic>.from(m));
            return null;
          })
          .where((m) => m != null)
          .cast<RoomMember>()
          .toList();

      final int initialLength = members.length;
      members.removeWhere((m) => m.uid == userId);

      if (members.length < initialLength) {
        transaction.update(roomRef, {
          'members': members.map((m) => m.toMap()).toList(),
          'memberCount': members.length,
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // =========================================================
  // FIX: LEAVE ROOM (Remove Member from DB)
  // =========================================================
  Future<void> _onLeaveRoom(
    LeaveRoomEvent event,
    Emitter<RoomState> emit,
  ) async {
    final user = _auth.currentUser;
    // Capture the room BEFORE we clear the state
    final activeRoom = state.activeChatRoom;

    // 1. Clear State immediately so UI updates (user sees they left)
    emit(
      state.copyWith(clearActiveChatRoom: true, clearActiveLivekitRoom: true),
    );

    if (user == null || activeRoom == null) {
      print("⚠️ [RoomBloc] Leave skipped: User or ActiveRoom is null.");
      return;
    }

    try {
      print(
        "🚪 [RoomBloc] Removing user ${user.uid} from room ${activeRoom.id}...",
      );
      final roomRef = _firestore.collection('rooms').doc(activeRoom.id);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;

        final currentData = snapshot.data()!;
        final rawList = currentData['members'] as List<dynamic>? ?? [];

        // 2. Parse List Safe & Sound
        final members = rawList
            .map((m) {
              if (m is Map<String, dynamic>) return RoomMember.fromMap(m);
              if (m is Map)
                return RoomMember.fromMap(Map<String, dynamic>.from(m));
              return null;
            })
            .where((m) => m != null)
            .cast<RoomMember>()
            .toList();

        // 3. Find and Remove the User
        final int initialLength = members.length;
        members.removeWhere((m) => m.uid == user.uid);

        if (members.length < initialLength) {
          // Only update if we actually removed someone
          transaction.update(roomRef, {
            'members': members.map((m) => m.toMap()).toList(),
            'memberCount': members.length, // Sync count
            'lastUpdatedAt': FieldValue.serverTimestamp(),
          });
          print("✅ [RoomBloc] User removed from Firestore.");
        } else {
          print("ℹ️ [RoomBloc] User was not in the list to begin with.");
        }
      });
    } catch (e) {
      print("❌ [RoomBloc] Failed to leave room in DB: $e");
    }
  }

  // =========================================================
  // 5. MODERATION
  // =========================================================
  // =========================================================
  Future<void> _onToggleSpotlight(
    ToggleSpotlightEvent event,
    Emitter<RoomState> emit,
  ) async {
    debugPrint("🏗️ [RoomBloc] ToggleSpotlight: ${event.userId}");
    try {
      await _firestore.collection('rooms').doc(event.roomId).update({
        'spotlightedUserId': event.userId,
      });
    } catch (e) {
      debugPrint("❌ [RoomBloc] Spotlight Error: $e");
    }
  }

  Future<void> _onUpdateActiveFeature(
    UpdateActiveFeatureEvent event,
    Emitter<RoomState> emit,
  ) async {
    try {
      await _firestore.collection('rooms').doc(event.roomId).update({
        'activeFeature': event.feature,
        'activeFeatureData': event.data,
      });
    } catch (e) {
      debugPrint("Error updating feature: $e");
    }
  }

  Future<void> _onUpdateRoomInfo(
    UpdateRoomInfoEvent event,
    Emitter<RoomState> emit,
  ) async {
    try {
      await _firestore.collection('rooms').doc(event.roomId).update({
        'title': event.title,
        'description': event.description,
      });
    } catch (e) {
      debugPrint("Error updating info: $e");
    }
  }
}
