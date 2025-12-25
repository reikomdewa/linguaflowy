// import 'dart:async';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:linguaflow/models/speak/room_member.dart';
// import 'package:uuid/uuid.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'speak_event.dart';
// import 'speak_state.dart';
// import '../../models/speak/speak_models.dart';
// import '../../services/speak/speak_service.dart';
// // ADDED FOR SPOTLIGHT
// import 'package:cloud_firestore/cloud_firestore.dart';

// class SpeakBloc extends Bloc<SpeakEvent, SpeakState> {
//   final _uuid = const Uuid();
//   final SpeakService _speakService = SpeakService();
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   // ADDED FOR SPOTLIGHT
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;

//   // Master lists holding the true data from the database
//   List<ChatRoom> _masterRooms = [];
//   List<Tutor> _masterTutors = [];
//   StreamSubscription? _roomsSubscription;
//   SpeakBloc() : super(const SpeakState()) {
//     // Basic UI and Loading
//     on<LoadSpeakData>(_onLoadSpeakData);
//     on<ChangeSpeakTab>(_onChangeSpeakTab);
//     on<FilterSpeakList>(_onFilterSpeakList);
//     on<ClearAllFilters>(_onClearAllFilters);

//     // Media and LiveKit Connection
//     on<RoomJoined>(_onRoomJoined);
//     on<LeaveRoomEvent>(_onRoomLeft);

//     // Room Management
//     on<CreateRoomEvent>(_onCreateRoom);
//     on<JoinRoomEvent>(_onJoinRoom);
//     on<DeleteRoomEvent>(_onDeleteRoom);

//     // NEW: Spotlight Event
//     on<ToggleSpotlightEvent>(_onToggleSpotlight);
//     on<KickUserEvent>(_onKickUser);
//     on<RoomsUpdatedEvent>(_onRoomsUpdated);
//     // Tutor Management
//     on<CreateTutorProfileEvent>(_onCreateTutorProfile);
//     on<DeleteTutorProfileEvent>(_onDeleteTutorProfile);
//   }
//   @override
//   Future<void> close() {
//     _roomsSubscription?.cancel();
//     return super.close();
//   }

//   // =========================================================
//   Future<void> _onLoadSpeakData(
//     LoadSpeakData event,
//     Emitter<SpeakState> emit,
//   ) async {
//     if (_masterRooms.isEmpty && _masterTutors.isEmpty) {
//       emit(state.copyWith(status: SpeakStatus.loading));
//     }

//     // 1. Load Tutors (Keep as Future if you don't need real-time tutors)
//     try {
//       final tutors = await _speakService.getTutors();
//       _masterTutors = tutors;
//       // Emit tutors immediately while waiting for rooms stream
//       _applyFiltersAndEmit(emit);
//     } catch (e) {
//       print("Load Tutors Error: $e");
//     }

//     // 2. LISTEN TO ROOMS (Real-time Stream)
//     // Cancel old subscription if refreshing
//     await _roomsSubscription?.cancel();

//     _roomsSubscription = _firestore
//         .collection('rooms')
//         .orderBy('createdAt', descending: true) // Optional: Sort by newest
//         .snapshots()
//         .listen((snapshot) {
//           // Convert Firestore Snapshot to your List<ChatRoom>
//           // NOTE: You need to ensure your ChatRoom model has a 'fromSnapshot' or 'fromMap' method.
//           // If you are using 'SpeakService' to parse, you might need to copy that logic here.
//           final List<ChatRoom> liveRooms = snapshot.docs.map((doc) {
//             final data = doc.data();

//             // --- ADAPT THIS PART TO MATCH YOUR MODEL ---
//             return ChatRoom(
//               id: doc.id,
//               hostId: data['hostId'] ?? '',
//               title: data['title'] ?? 'Untitled',
//               description: data['description'] ?? '',
//               language: data['language'] ?? 'English',
//               level: data['level'] ?? 'Beginner',
//               memberCount: data['memberCount'] ?? 0,
//               maxMembers: data['maxMembers'] ?? 10,
//               isPaid: data['isPaid'] ?? false,
//               hostName: data['hostName'],
//               hostAvatarUrl: data['hostAvatarUrl'],
//               // Parse members list carefully
//               members: (data['members'] as List<dynamic>? ?? [])
//                   .map(
//                     (m) => RoomMember(
//                       uid: m['uid'],
//                       displayName: m['displayName'],
//                       avatarUrl: m['avatarUrl'],
//                       joinedAt:
//                           (m['joinedAt'] as Timestamp?)?.toDate() ??
//                           DateTime.now(),
//                       isHost: m['isHost'] ?? false,
//                     ),
//                   )
//                   .toList(),
//               createdAt:
//                   (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
//               roomType: data['roomType'] ?? 'audio',
//               tags: List<String>.from(data['tags'] ?? []),
//               spotlightedUserId: data['spotlightedUserId'],
//             );
//             // -------------------------------------------
//           }).toList();

//           // Trigger the internal event
//           add(RoomsUpdatedEvent(liveRooms));
//         });
//   }

//   // <--- 4. NEW HANDLER TO UPDATE STATE
//   void _onRoomsUpdated(RoomsUpdatedEvent event, Emitter<SpeakState> emit) {
//     _masterRooms = event.rooms;
//     // This will re-run filters and update the UI
//     _applyFiltersAndEmit(emit);
//   }

//   // =========================================================
//   // THE MASTER FILTER ENGINE
//   // =========================================================
//   void _applyFiltersAndEmit(
//     Emitter<SpeakState> emit, {
//     Map<String, String>? newFilters,
//     String? newSearchQuery,
//   }) {
//     final filters = newFilters ?? state.filters;
//     final searchStr = (newSearchQuery ?? state.searchQuery ?? "").toLowerCase();
//     final currentUser = _auth.currentUser;

//     // Define "Stale": Created > 5 mins ago AND has 0 members
//     // This hides "Ghost Rooms" where the host crashed before joining.
//     final DateTime staleCutoff = DateTime.now().subtract(const Duration(minutes: 5));

//     // 1. Filter Rooms Logic
//     final filteredRooms = _masterRooms.where((room) {
//       // --- GHOST FILTER START ---
//       // If nobody is in the room and it's older than 5 mins, hide it from UI.
//       if (room.memberCount == 0 && room.createdAt.isBefore(staleCutoff)) {
//         return false; 
//       }
//       // --- GHOST FILTER END ---

//       bool matches = true;

//       // Existing Filters
//       if (filters.containsKey('Language Level')) {
//         matches = matches && room.level == filters['Language Level'];
//       }
//       if (filters.containsKey('Paid')) {
//         matches =
//             matches && (filters['Paid'] == 'Free' ? !room.isPaid : room.isPaid);
//       }
//       if (searchStr.isNotEmpty) {
//         matches =
//             matches &&
//             (room.title.toLowerCase().contains(searchStr) ||
//                 (room.hostName?.toLowerCase().contains(searchStr) ?? false));
//       }
//       return matches;
//     }).toList();

//     // 2. Filter Tutors Logic
//     final filteredTutors = _masterTutors.where((tutor) {
//       // Always show the current user's own tutor profile
//       if (currentUser != null && tutor.userId == currentUser.uid) return true;

//       bool matches = true;
//       if (filters.containsKey('Language Level')) {
//         matches = matches && tutor.level == filters['Language Level'];
//       }
//       if (filters.containsKey('Specialty')) {
//         matches = matches && tutor.specialties.contains(filters['Specialty']);
//       }
//       if (searchStr.isNotEmpty) {
//         matches = matches && tutor.name.toLowerCase().contains(searchStr);
//       }
//       return matches;
//     }).toList();

//     emit(
//       state.copyWith(
//         status: SpeakStatus.success,
//         rooms: List.from(filteredRooms),
//         tutors: List.from(filteredTutors),
//         filters: filters,
//         searchQuery: newSearchQuery ?? state.searchQuery,
//       ),
//     );
//   }

//   // =========================================================
//   // DATA LOADING
//   // =========================================================

//   // =========================================================
//   // ROOM HANDLERS
//   // =========================================================

//   Future<void> _onCreateRoom(
//     CreateRoomEvent event,
//     Emitter<SpeakState> emit,
//   ) async {
//     final user = _auth.currentUser;
//     if (user == null) return;

//     final newRoom = ChatRoom(
//       id: _uuid.v4(),
//       hostId: user.uid,
//       title: event.topic,
//       description: event.description ?? "",
//       language: event.language,
//       level: event.level,
//       memberCount: 1,
//       maxMembers: event.maxMembers,
//       isPaid: event.isPaid,
//       hostName: user.displayName,
//       hostAvatarUrl: user.photoURL,
//       members: [
//         RoomMember(
//           uid: user.uid,
//           displayName: user.displayName,
//           avatarUrl: user.photoURL,
//           joinedAt: DateTime.now(),
//           isHost: true,
//         ),
//       ],
//       createdAt: DateTime.now(),
//       expireAt: DateTime.now().add(const Duration(hours: 24)),
//       roomType: event.roomType,
//       tags: event.tags,
//     );

//     _masterRooms.insert(0, newRoom);
//     _applyFiltersAndEmit(emit);

//     _speakService
//         .createRoom(newRoom)
//         .catchError((e) => print("Firebase Room Error: $e"));
//   }

//   Future<void> _onJoinRoom(
//     JoinRoomEvent event,
//     Emitter<SpeakState> emit,
//   ) async {
//     final user = _auth.currentUser;
//     if (user == null) return;

//     try {
//       ChatRoom? updatedRoom;
//       // We need to create a new list for _masterRooms to trigger updates safely
//       final newMasterList = _masterRooms.map((room) {
//         if (room.id == event.room.id) {
//           // Check if already in the room
//           if (room.members.any((m) => m.uid == user.uid)) return room;

//           updatedRoom = room.copyWith(
//             members: List<RoomMember>.from(room.members)
//               ..add(
//                 RoomMember(
//                   uid: user.uid,
//                   displayName: user.displayName,
//                   avatarUrl: user.photoURL,
//                   joinedAt: DateTime.now(),
//                 ),
//               ),
//             memberCount: room.memberCount + 1,
//           );
//           return updatedRoom!;
//         }
//         return room;
//       }).toList();

//       _masterRooms = newMasterList;

//       if (updatedRoom != null) {
//         _applyFiltersAndEmit(emit);
//         await _speakService.updateRoomMembers(
//           updatedRoom!.id,
//           updatedRoom!.members,
//           updatedRoom!.memberCount,
//         );
//       }
//     } catch (e) {
//       print("Join Room Error: $e");
//     }
//   }

//   Future<void> _onDeleteRoom(
//     DeleteRoomEvent event,
//     Emitter<SpeakState> emit,
//   ) async {
//     _masterRooms.removeWhere((r) => r.id == event.roomId);
//     _applyFiltersAndEmit(emit);

//     try {
//       await _speakService.deleteRoom(event.roomId);
//     } catch (e) {
//       print("Delete Room Error: $e");
//     }
//   }

//   // --- NEW: SPOTLIGHT HANDLER ---
//   Future<void> _onToggleSpotlight(
//     ToggleSpotlightEvent event,
//     Emitter<SpeakState> emit,
//   ) async {
//     try {
//       // 1. Optimistic Update (Optional, makes UI snappy for Host)
//       final index = _masterRooms.indexWhere((r) => r.id == event.roomId);
//       if (index != -1) {
//         final updatedRoom = _masterRooms[index].copyWith(
//           spotlightedUserId: event.userId,
//         );
//         _masterRooms[index] = updatedRoom;
//         _applyFiltersAndEmit(emit); // Refresh UI list
//       }

//       // 2. Persist to Firestore (This triggers updates for everyone else)
//       await _firestore.collection('rooms').doc(event.roomId).update({
//         'spotlightedUserId': event.userId,
//       });
//     } catch (e) {
//       print("Error toggling spotlight: $e");
//     }
//   }

//   Future<void> _onKickUser(
//     KickUserEvent event,
//     Emitter<SpeakState> emit,
//   ) async {
//     try {
//       // 1. FIX: Use correct collection name 'rooms'
//       final roomRef = _firestore.collection('rooms').doc(event.roomId);

//       final roomSnapshot = await roomRef.get();
//       if (!roomSnapshot.exists) return;

//       final data = roomSnapshot.data() as Map<String, dynamic>;
//       // Get the current members array
//       final membersList = List<Map<String, dynamic>>.from(
//         data['members'] ?? [],
//       );

//       // 2. FIX: Remove the user.
//       // We check both 'uid' and 'displayName' because LiveKit identity
//       // might be set to the user's Name or their UID depending on your token server.
//       final int initialLength = membersList.length;

//       membersList.removeWhere((m) {
//         final uid = m['uid'] as String?;
//         final name = m['displayName'] as String?;
//         // Check if the target ID matches either the stored UID or Name
//         return uid == event.userId || name == event.userId;
//       });

//       // Only update if someone was actually removed
//       if (membersList.length < initialLength) {
//         await roomRef.update({
//           'members': membersList,
//           'memberCount': membersList.length,
//         });
//         print("✅ User ${event.userId} kicked successfully.");
//       } else {
//         print("⚠️ User ${event.userId} not found in members list.");
//       }
//     } catch (e) {
//       print("Error kicking user: $e");
//     }
//   }
//   // =========================================================
//   // TUTOR HANDLERS
//   // =========================================================

//   Future<void> _onCreateTutorProfile(
//     CreateTutorProfileEvent event,
//     Emitter<SpeakState> emit,
//   ) async {
//     final user = _auth.currentUser;
//     if (user == null) return;

//     final newTutor = Tutor(
//       id: user.uid,
//       userId: user.uid,
//       name: event.name,
//       imageUrl: event.imageUrl,
//       description: event.description,
//       countryOfBirth: event.countryOfBirth,
//       isNative: event.isNative,
//       language: event.language,
//       level: event.level,
//       specialties: event.specialties,
//       otherLanguages: event.otherLanguages,
//       pricePerHour: event.pricePerHour,
//       availability: event.availability,
//       lessons: event.lessons,
//       metadata: event.metadata,
//       createdAt: DateTime.now(),
//       lastUpdatedAt: DateTime.now(),
//       isOnline: true,
//       rating: 5.0,
//       reviews: 0,
//     );

//     final index = _masterTutors.indexWhere((t) => t.userId == user.uid);
//     if (index != -1) {
//       _masterTutors[index] = newTutor;
//     } else {
//       _masterTutors.insert(0, newTutor);
//     }

//     _applyFiltersAndEmit(emit);

//     _speakService
//         .createTutorProfile(newTutor)
//         .catchError((e) => print("Firebase Tutor Error: $e"));
//   }

//   Future<void> _onDeleteTutorProfile(
//     DeleteTutorProfileEvent event,
//     Emitter<SpeakState> emit,
//   ) async {
//     _masterTutors.removeWhere((t) => t.id == event.tutorId);
//     _applyFiltersAndEmit(emit);

//     try {
//       await _speakService.deleteTutorProfile(event.tutorId);
//     } catch (e) {
//       print("Delete Tutor Error: $e");
//     }
//   }

//   // =========================================================
//   // UTILITY & STATE HANDLERS
//   // =========================================================

//   void _onFilterSpeakList(FilterSpeakList event, Emitter<SpeakState> emit) {
//     final Map<String, String> updatedFilters = Map.from(state.filters);

//     if (event.category != null) {
//       if (event.query != null) {
//         updatedFilters[event.category!] = event.query!;
//       } else {
//         updatedFilters.remove(event.category);
//       }
//     }

//     _applyFiltersAndEmit(
//       emit,
//       newFilters: updatedFilters,
//       newSearchQuery: event.category == null ? event.query : state.searchQuery,
//     );
//   }

//   void _onClearAllFilters(ClearAllFilters event, Emitter<SpeakState> emit) {
//     emit(state.copyWith(resetFilters: true));
//     _applyFiltersAndEmit(emit, newFilters: {}, newSearchQuery: "");
//   }

//   void _onChangeSpeakTab(ChangeSpeakTab event, Emitter<SpeakState> emit) {
//     final newTab = event.tabIndex == 0
//         ? SpeakTab.all
//         : (event.tabIndex == 1 ? SpeakTab.tutors : SpeakTab.rooms);
//     emit(state.copyWith(currentTab: newTab));
//   }

//   void _onRoomJoined(RoomJoined event, Emitter<SpeakState> emit) =>
//       emit(state.copyWith(activeRoom: event.room));

//   void _onRoomLeft(LeaveRoomEvent event, Emitter<SpeakState> emit) =>
//       emit(state.copyWith(clearActiveRoom: true));
// }
