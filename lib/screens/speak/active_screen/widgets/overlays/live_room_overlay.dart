import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:linguaflow/core/globals.dart';
import 'package:linguaflow/models/speak/room_member.dart';
import 'package:linguaflow/models/speak/speak_models.dart';
import 'package:linguaflow/screens/speak/active_screen/managers/room_global_manager.dart';
import 'package:linguaflow/screens/speak/active_screen/widgets/overlays/full_screen_participant.dart';
import 'package:linguaflow/screens/speak/active_screen/widgets/overlays/leave_comfirm_dialog.dart';
import 'package:linguaflow/screens/speak/active_screen/widgets/sheets/board_requests_sheet.dart';
import 'package:linguaflow/screens/speak/active_screen/widgets/sheets/youtube_requests_sheet.dart'; // Ensure this exists
import 'package:linguaflow/screens/speak/active_screen/widgets/youtube_input_dialog.dart'; // Ensure this exists
import 'package:livekit_client/livekit_client.dart';

import 'package:linguaflow/screens/speak/widgets/sheets/room_chat_sheet.dart';
import 'package:linguaflow/services/speak/chat_service.dart';

// BLOC EVENTS
import 'package:linguaflow/blocs/speak/room/room_bloc.dart';
import 'package:linguaflow/blocs/speak/room/room_event.dart' hide RoomEvent;

// COMPONENT IMPORTS
import 'morphing_room_card.dart';
import 'room_menu_sheet.dart';
import 'participant_options_sheet.dart';

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

  // -- UI STATE FLAGS --
  bool _isChatOpen = false;
  bool _isSettingsOpen = false;
  bool _isLeaveConfirmOpen = false;

  // YouTube & Requests Flags
  bool _isYouTubeInputOpen = false;
  bool _isYouTubeRequestsOpen = false;
  bool _isBoardRequestsOpen = false;

  // Track who we are accepting a request from
  String? _pendingRequestUserId;

  Participant? _selectedParticipant;
  Participant? _fullScreenParticipant;
  String? _currentSpotlightId;
  bool _hasSeenSelfInFirestore = false;

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
          _resetUIState();
          _selectedParticipant = null;
          _fullScreenParticipant = null;
          _hasSeenSelfInFirestore = false;
          _currentSpotlightId = null;
        });
      }
    }
    if (mounted) setState(() {});
  }

  void _resetUIState() {
    _isChatOpen = false;
    _isSettingsOpen = false;
    _isLeaveConfirmOpen = false;
    _isYouTubeInputOpen = false;
    _isYouTubeRequestsOpen = false;
    _isBoardRequestsOpen = false;
    _pendingRequestUserId = null;
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
      _resetUIState(); // Close all sheets/dialogs
    });
  }

  @override
  Widget build(BuildContext context) {
    final manager = RoomGlobalManager();
    if (!manager.isActive) return const SizedBox.shrink();

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currentUser = FirebaseAuth.instance.currentUser;
    final isHost = manager.roomData?.hostId == currentUser?.uid;

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
                _resetUIState();
                _selectedParticipant = null;
                _isChatOpen = true;
                _publicUnreadCount = 0;
                _lastReadCount = _chatService.currentMessages.length;
              });
            },
            onOpenMenu: () {
              setState(() {
                _resetUIState();
                _selectedParticipant = null;
                _isSettingsOpen = true;
              });
            },
            onClosePress: () {
              setState(() {
                _resetUIState();
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

        // CHAT SHEET
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

        // SETTINGS MENU
        if (_isSettingsOpen && manager.isExpanded) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _isSettingsOpen = false),
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),
          ),
          RoomMenuSheet(
            manager: manager,
            isHost: isHost,
            onClose: () => setState(() => _isSettingsOpen = false),
            // Updated Callback: Opens Requests
            onOpenRequests: () {
              setState(() {
                _isSettingsOpen = false;
                _isBoardRequestsOpen = true; // Use separate flag if distinct
                // Or if combining requests, just use one flag.
                // Assuming you have separate lists, let's open Board requests first
                // OR you can update RoomMenuSheet to split them.
                // For now, let's assume this opens Youtube Requests as requested by logic:
                _isYouTubeRequestsOpen = true;
              });
            },
            // Updated Callback: Opens Youtube Input
            onOpenYouTube: () {
              setState(() {
                _isSettingsOpen = false;
                _pendingRequestUserId = null; // Clean entry
                _isYouTubeInputOpen = true;
              });
            },
          ),
        ],

        // BOARD REQUESTS
        if (_isBoardRequestsOpen &&
            manager.isExpanded &&
            manager.roomData != null) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _isBoardRequestsOpen = false),
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),
          ),
          BoardRequestsSheet(
            room: manager.roomData!,
            onClose: () => setState(() => _isBoardRequestsOpen = false),
          ),
        ],
  // YOUTUBE REQUESTS SHEET (Host View)
        if (_isYouTubeRequestsOpen && manager.isExpanded && manager.roomData != null) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _isYouTubeRequestsOpen = false),
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),
          ),
          YouTubeRequestsSheet(
            room: manager.roomData!,
            onClose: () => setState(() => _isYouTubeRequestsOpen = false),
            // UPDATED CALLBACK:
            onAccept: (url, requestMap) {
              // 1. Close Sheet
              setState(() => _isYouTubeRequestsOpen = false);
              
              // 2. Play Immediately (No Input Dialog needed for host here)
              context.read<RoomBloc>().add(
                PlayYouTubeVideoEvent(
                  roomId: manager.roomData!.id,
                  videoUrl: url,
                  requestToRemove: requestMap, // Remove the request
                )
              );
            },
          ),
        ],

        // YOUTUBE INPUT DIALOG (Used by Host to Play Direct, OR Guest to Request)
        if (_isYouTubeInputOpen && manager.isExpanded) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _isYouTubeInputOpen = false),
              child: Container(color: Colors.black.withOpacity(0.7)),
            ),
          ),
          YouTubeInputDialog(
            onCancel: () => setState(() => _isYouTubeInputOpen = false),
            onPlay: (url) {
              setState(() => _isYouTubeInputOpen = false);
              
              if (manager.roomData == null) return;
              final roomId = manager.roomData!.id;

              if (isHost) {
                // HOST: Plays directly
                context.read<RoomBloc>().add(
                  PlayYouTubeVideoEvent(roomId: roomId, videoUrl: url)
                );
              } else {
                // GUEST: Sends Request with URL
                if (currentUser != null) {
                  context.read<RoomBloc>().add(
                    RequestYouTubeAccessEvent(
                      roomId: roomId,
                      userId: currentUser.uid,
                      videoUrl: url,
                    )
                  );
                  // Optional: Show snackbar "Request Sent"
                }
              }
            },
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
            amIHost: isHost,
            currentSpotlightId: _currentSpotlightId,
            roomData: manager.roomData!,
            onClose: () => setState(() => _selectedParticipant = null),
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

        // LEAVE CONFIRM
        if (_isLeaveConfirmOpen && manager.isExpanded) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _isLeaveConfirmOpen = false),
              child: Container(color: Colors.black.withOpacity(0.6)),
            ),
          ),
          LeaveConfirmDialog(
            roomData: manager.roomData,
            onCancel: () => setState(() => _isLeaveConfirmOpen = false),
            onConfirm: () {
              setState(() => _isLeaveConfirmOpen = false);
              if (isHost && manager.roomData != null) {
                context.read<RoomBloc>().add(
                  DeleteRoomEvent(manager.roomData!.id),
                );
              } else {
                context.read<RoomBloc>().add(LeaveRoomEvent());
              }
              manager.leaveRoom();
            },
          ),
        ],
      ],
    );
  }
}
