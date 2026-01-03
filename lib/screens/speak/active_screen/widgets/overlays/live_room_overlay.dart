import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:linguaflow/core/globals.dart';
import 'package:linguaflow/models/speak/room_member.dart';
import 'package:linguaflow/models/speak/speak_models.dart';
import 'package:linguaflow/screens/speak/active_screen/managers/room_global_manager.dart';
import 'package:linguaflow/screens/speak/active_screen/widgets/overlays/leave_comfirm_dialog.dart';
import 'package:linguaflow/screens/speak/active_screen/widgets/sheets/board_requests_sheet.dart';
import 'package:livekit_client/livekit_client.dart';

import 'package:linguaflow/screens/speak/widgets/sheets/room_chat_sheet.dart';
import 'package:linguaflow/screens/speak/widgets/full_screen_participant.dart';
import 'package:linguaflow/services/speak/chat_service.dart';

// BLOC EVENTS (Needed for the Leave Logic)
import 'package:linguaflow/blocs/speak/room/room_bloc.dart';
import 'package:linguaflow/blocs/speak/room/room_event.dart'
    hide RoomEvent; // Hide LiveKit collision

// COMPONENT IMPORTS
import 'morphing_room_card.dart';
import 'room_menu_sheet.dart';
import 'participant_options_sheet.dart';
// Assuming your dialog is in a file like this, or imported from room_sheets.dart

class LiveRoomOverlay extends StatefulWidget {
  const LiveRoomOverlay({super.key});

  @override
  State<LiveRoomOverlay> createState() => _LiveRoomOverlayState();
}

class _LiveRoomOverlayState extends State<LiveRoomOverlay> {
  EventsListener<RoomEvent>? _listener;
  List<Participant> _participants = [];

  final ChatService _chatService = ChatService();
  StreamSubscription? _chatSubscription;
  StreamSubscription? _roomDocSubscription;

  int _publicUnreadCount = 0;
  int _lastReadCount = 0;

  bool _isChatOpen = false;
  bool _isSettingsOpen = false;
  bool _isLeaveConfirmOpen = false;

  Participant? _selectedParticipant;
  Participant? _fullScreenParticipant;
  String? _currentSpotlightId;
  bool _hasSeenSelfInFirestore = false;
  bool _isRequestsOpen = false;
  @override
  void initState() {
    super.initState();
    RoomGlobalManager().addListener(_onManagerChanged);
  }

  @override
  void dispose() {
    RoomGlobalManager().removeListener(_onManagerChanged);
    _listener?.dispose();
    _chatSubscription?.cancel();
    _roomDocSubscription?.cancel();
    super.dispose();
  }

  void _onManagerChanged() {
    final manager = RoomGlobalManager();
    if (manager.isActive) {
      if (_listener == null) {
        _setupLiveKitListeners(manager.livekitRoom!);
        _setupChatListener();
        _setupFirestoreListeners(manager.roomData!.id);
        _refreshParticipants();
      }
    } else {
      _cleanupListeners();
      if (mounted) {
        setState(() {
          _isChatOpen = false;
          _isSettingsOpen = false;
          _isLeaveConfirmOpen = false;
          _selectedParticipant = null;
          _fullScreenParticipant = null;
          _hasSeenSelfInFirestore = false;
          _currentSpotlightId = null;
        });
      }
    }
    if (mounted) setState(() {});
  }

  void _resolveSpotlight(String? spotlightId) {
    if (spotlightId == null) {
      if (_currentSpotlightId != null) {
        setState(() {
          _currentSpotlightId = null;
          _fullScreenParticipant = null;
        });
      }
      return;
    }

    _currentSpotlightId = spotlightId;
    final room = RoomGlobalManager().livekitRoom;
    if (room == null) return;

    Participant? foundUser;
    if (room.localParticipant?.identity == spotlightId) {
      foundUser = room.localParticipant;
    } else {
      try {
        foundUser = room.remoteParticipants.values.firstWhere(
          (p) => p.identity == spotlightId,
        );
      } catch (_) {}
    }

    if (foundUser != null && _fullScreenParticipant != foundUser) {
      setState(() => _fullScreenParticipant = foundUser);
    }
  }

  void _setupFirestoreListeners(String roomId) {
    _roomDocSubscription?.cancel();
    final docRef = FirebaseFirestore.instance.collection('rooms').doc(roomId);

    _roomDocSubscription = docRef.snapshots().listen((snapshot) {
      if (!snapshot.exists || !mounted) {
        RoomGlobalManager().leaveRoom();
        return;
      }

      final data = snapshot.data();
      if (data == null) return;

      final manager = RoomGlobalManager();
      final updatedRoom = ChatRoom.fromMap(data, snapshot.id);
      manager.syncFromFirestore(updatedRoom);

      // KICK LOGIC
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final members = updatedRoom.members;
        final myUid = currentUser.uid;
        final amIInList = members.any((m) => m.uid == myUid);
        final amIHost = updatedRoom.hostId == myUid;

        if (amIInList || amIHost) _hasSeenSelfInFirestore = true;

        if (_hasSeenSelfInFirestore &&
            !amIInList &&
            !amIHost &&
            manager.isActive) {
          manager.leaveRoom();
          if (navigatorKey.currentContext != null) {
            ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
              const SnackBar(
                content: Text("You have been kicked."),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      _resolveSpotlight(updatedRoom.spotlightedUserId);
    });
  }

  void _setupLiveKitListeners(Room room) {
    _listener = room.createListener();
    _listener!
      ..on<ParticipantConnectedEvent>((_) => _refreshParticipants())
      ..on<ParticipantDisconnectedEvent>((_) => _refreshParticipants())
      ..on<TrackSubscribedEvent>((_) => _safeSetState())
      ..on<TrackUnsubscribedEvent>((_) => _safeSetState())
      ..on<LocalTrackPublishedEvent>((_) => _safeSetState())
      ..on<LocalTrackUnpublishedEvent>((_) => _safeSetState())
      ..on<RoomDisconnectedEvent>((_) => RoomGlobalManager().leaveRoom());
  }

  void _refreshParticipants() {
    final room = RoomGlobalManager().livekitRoom;
    if (room == null) return;
    setState(() {
      _participants = [
        if (room.localParticipant != null) room.localParticipant!,
        ...room.remoteParticipants.values,
      ];
    });
    if (_currentSpotlightId != null) _resolveSpotlight(_currentSpotlightId);
  }

  void _setupChatListener() {
    _lastReadCount = _chatService.currentMessages.length;
    _chatSubscription = _chatService.messagesStream.listen((messages) {
      if (!mounted) return;
      if (_isChatOpen) {
        _lastReadCount = messages.length;
        if (_publicUnreadCount > 0) setState(() => _publicUnreadCount = 0);
      } else {
        final diff = messages.length - _lastReadCount;
        if (diff > 0) setState(() => _publicUnreadCount = diff);
      }
    });
  }

  void _cleanupListeners() {
    _listener?.dispose();
    _listener = null;
    _chatSubscription?.cancel();
    _roomDocSubscription?.cancel();
    _participants.clear();
  }

  void _safeSetState() {
    if (mounted) setState(() {});
  }

  void _handleParticipantTap(Participant p) {
    setState(() {
      _selectedParticipant = p;
      _isChatOpen = false;
      _isSettingsOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final manager = RoomGlobalManager();
    if (!manager.isActive) return const SizedBox.shrink();

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Stack(
      children: [
        if (manager.isExpanded)
          Positioned.fill(
            child: GestureDetector(
              onTap: manager.collapse,
              child: Container(color: Colors.transparent),
            ),
          ),

        Align(
          alignment: manager.isExpanded
              ? Alignment.center
              : Alignment.bottomRight,
          child: MorphingRoomCard(
            manager: manager,
            participants: _participants,
            unreadCount: _publicUnreadCount,
            onOpenChat: () {
              setState(() {
                _isSettingsOpen = false;
                _isLeaveConfirmOpen = false;
                _isRequestsOpen = false;
                _selectedParticipant = null;
                _isChatOpen = true;
                _publicUnreadCount = 0;
                _lastReadCount = _chatService.currentMessages.length;
              });
            },
            onOpenMenu: () {
              setState(() {
                _isChatOpen = false;
                _isLeaveConfirmOpen = false;
                _isRequestsOpen = false;
                _selectedParticipant = null;
                _isSettingsOpen = true;
              });
            },
            onClosePress: () {
              setState(() {
                _isChatOpen = false;
                _isSettingsOpen = false;
                _isRequestsOpen = false;
                _selectedParticipant = null;
                _isLeaveConfirmOpen = true;
              });
            },
            onParticipantTap: _handleParticipantTap,
          ),
        ),

        // FULL SCREEN VIEW
        if (_fullScreenParticipant != null && manager.isExpanded)
          Positioned.fill(
            child: Stack(
              children: [
                FullScreenParticipantScreen(
                  participant: _fullScreenParticipant!,
                ),
                Positioned(
                  top: 40,
                  left: 20,
                  child: Material(
                    type: MaterialType.transparency,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 30),
                      onPressed: () =>
                          setState(() => _fullScreenParticipant = null),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // CHAT
        if (_isChatOpen && manager.isExpanded) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _isChatOpen = false),
              child: Container(color: Colors.black.withOpacity(0.6)),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.75,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: RoomChatSheet(
                      room: manager.livekitRoom!,
                      onClose: () => setState(() => _isChatOpen = false),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],

        // SETTINGS
        if (_isSettingsOpen && manager.isExpanded) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _isSettingsOpen = false),
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),
          ),
          RoomMenuSheet(
            manager: manager,
            isHost:
                manager.roomData?.hostId ==
                FirebaseAuth.instance.currentUser?.uid,
            onClose: () => setState(() => _isSettingsOpen = false),
            onOpenRequests: () {
              setState(() {
                _isSettingsOpen = false; // Close menu
                _isRequestsOpen = true; // Open requests
              });
            },
          ),
        ],
        // --- NEW: BOARD REQUESTS SHEET ---
        if (_isRequestsOpen && manager.isExpanded) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _isRequestsOpen = false),
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),
          ),
          BoardRequestsSheet(
            room: manager.roomData!,
            onClose: () => setState(() => _isRequestsOpen = false),
          ),
        ],

        // PARTICIPANT OPTIONS
        if (_selectedParticipant != null && manager.isExpanded) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _selectedParticipant = null),
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),
          ),
          ParticipantOptionsSheet(
            targetParticipant: _selectedParticipant!,
            amIHost:
                manager.roomData?.hostId ==
                FirebaseAuth.instance.currentUser?.uid,
            currentSpotlightId: _currentSpotlightId,
            roomData: manager.roomData!,
            onClose: () => setState(() => _selectedParticipant = null),

            // Callbacks for actions
            onSetFullScreen: (p) {
              setState(() {
                _fullScreenParticipant = p;
                _selectedParticipant = null;
              });
            },
            onToggleSpotlight: (userId) {
              context.read<RoomBloc>().add(
                ToggleSpotlightEvent(
                  roomId: manager.roomData!.id,
                  userId: userId,
                ),
              );
            },
            onKickUser: (userId) {
              context.read<RoomBloc>().add(
                KickUserEvent(roomId: manager.roomData!.id, userId: userId),
              );
            },
          ),
        ],

        // --- CUSTOM LEAVE CONFIRM DIALOG ---
        if (_isLeaveConfirmOpen && manager.isExpanded) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _isLeaveConfirmOpen = false),
              child: Container(color: Colors.black.withOpacity(0.6)),
            ),
          ),
          // Here is your custom dialog logic implementation
          LeaveConfirmDialog(
            roomData: manager.roomData,
            onCancel: () => setState(() => _isLeaveConfirmOpen = false),
            onConfirm: () {
              // 1. Close UI
              setState(() => _isLeaveConfirmOpen = false);

              // 2. Determine if Host or Guest logic needed for Bloc
              final isHost =
                  manager.roomData?.hostId ==
                  FirebaseAuth.instance.currentUser?.uid;

              if (isHost && manager.roomData != null) {
                // Host Ending Room
                context.read<RoomBloc>().add(
                  DeleteRoomEvent(manager.roomData!.id),
                );
              } else {
                // Guest Leaving
                context.read<RoomBloc>().add(LeaveRoomEvent());
              }

              // 3. Disconnect LiveKit locally
              manager.leaveRoom();
            },
          ),
        ],
      ],
    );
  }
}
