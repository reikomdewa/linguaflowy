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
import 'package:linguaflow/screens/speak/active_screen/widgets/sheets/join_requests_sheet.dart';
import 'package:linguaflow/screens/speak/active_screen/widgets/sheets/youtube_requests_sheet.dart';
import 'package:linguaflow/screens/speak/active_screen/widgets/youtube_input_dialog.dart';
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

  // -- NEW FLAGS FOR STACK WIDGETS --
  bool _isUserManagementOpen = false;
  bool _isBanningMode = false; // true = ban, false = mute
  bool _isEditRoomOpen = false;
  bool _isReportOpen = false;
  bool _isJoinRequestsOpen = false;
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

  // UPDATE THIS METHOD
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
    // REMOVED: if (mounted) setState(() {}); <--- This caused unnecessary double rebuilds
    if (mounted) setState(() {}); // Keep one, but ensure it doesn't conflict
  }
  void _resetUIState() {
    _isChatOpen = false;
    _isSettingsOpen = false;
    _isLeaveConfirmOpen = false;
    _isYouTubeInputOpen = false;
    _isYouTubeRequestsOpen = false;
    _isBoardRequestsOpen = false;
    _pendingRequestUserId = null;

    // Reset new flags
    _isUserManagementOpen = false;
    _isEditRoomOpen = false;
    _isReportOpen = false;
    _isJoinRequestsOpen = false;
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
      ..on<TrackMutedEvent>((_) => _safeSetState()) // Capture Mutes
      ..on<TrackUnmutedEvent>((_) => _safeSetState()) // Capture Unmutes
      ..on<RoomDisconnectedEvent>((_) => RoomGlobalManager().leaveRoom());
  }

 void _refreshParticipants() {
    final room = RoomGlobalManager().livekitRoom;
    if (room == null) return;
    
    // FIX: Explicitly type the list as <Participant> so Dart knows what it contains
    final List<Participant> newParticipants = [
      if (room.localParticipant != null) room.localParticipant!,
      ...room.remoteParticipants.values,
    ];

    // Check if the selected participant (menu open) is still in the room
    if (_selectedParticipant != null) {
      // Now 'p' is correctly identified as a Participant, so .identity works
      final stillExists = newParticipants.any((p) => p.identity == _selectedParticipant!.identity);
      if (!stillExists) {
        // If the user I was looking at left (or got banned), close the menu
        _selectedParticipant = null;
      }
    }

    // Check if full screen participant still exists
    if (_fullScreenParticipant != null) {
       final stillExists = newParticipants.any((p) => p.identity == _fullScreenParticipant!.identity);
       if (!stillExists) {
         _fullScreenParticipant = null;
       }
    }

    if (mounted) {
      setState(() {
        _participants = newParticipants;
      });
    }
    
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
      _resetUIState();
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
            // Callbacks
            onOpenRequests: () {
              setState(() {
                _isSettingsOpen = false;
                // Check for Join Requests first (Priority)
                if (manager.roomData!.joinRequests.isNotEmpty) {
                  _isJoinRequestsOpen = true;
                } else {
                  _isBoardRequestsOpen = true;
                  _isYouTubeRequestsOpen = true;
                }
              });
            },
            onOpenYouTube: () {
              setState(() {
                _isSettingsOpen = false;
                _pendingRequestUserId = null;
                _isYouTubeInputOpen = true;
              });
            },
            onOpenUserManagement: (isBanning) {
              setState(() {
                _isSettingsOpen = false;
                _isBanningMode = isBanning;
                _isUserManagementOpen = true;
              });
            },
            onOpenEdit: () {
              setState(() {
                _isSettingsOpen = false;
                _isEditRoomOpen = true;
              });
            },
            onOpenReport: () {
              setState(() {
                _isSettingsOpen = false;
                _isReportOpen = true;
              });
            },
          ),
        ],

        // --- NEW: USER MANAGEMENT (MUTES/BANS) ---
        if (_isUserManagementOpen &&
            manager.isExpanded &&
            manager.roomData != null) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _isUserManagementOpen = false),
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),
          ),
          UserManagementSheetStack(
            isBanning: _isBanningMode,
            members: manager.roomData!.members,
            roomId: manager.roomData!.id,
            onClose: () => setState(() => _isUserManagementOpen = false),
            manager: manager,
          ),
        ],

        // --- NEW: EDIT ROOM DIALOG ---
        if (_isEditRoomOpen &&
            manager.isExpanded &&
            manager.roomData != null) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _isEditRoomOpen = false),
              child: Container(color: Colors.black.withOpacity(0.7)),
            ),
          ),
          EditRoomDialogStack(
            key: const ValueKey('edit_room_dialog'), // Prevents state loss
            room: manager.roomData!,
            onClose: () => setState(() => _isEditRoomOpen = false),
          ),
        ],
        // --- JOIN REQUESTS (BANNED USERS) ---
        // --- JOIN REQUESTS (BANNED USERS) ---
        if (_isJoinRequestsOpen &&
            manager.isExpanded &&
            manager.roomData != null) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _isJoinRequestsOpen = false),
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),
          ),
          JoinRequestsSheet(
            room: manager.roomData!,
            onClose: () => setState(() => _isJoinRequestsOpen = false),

            // ACCEPT HANDLER
            onAccept: (userId, req) {
              // This triggers the new robust Transaction logic
              context.read<RoomBloc>().add(
                ApproveRejoinEvent(
                  roomId: manager.roomData!.id,
                  userId: userId,
                  requestMap: req,
                ),
              );
              // Auto-close if this was the last request
              if (manager.roomData!.joinRequests.length <= 1) {
                setState(() => _isJoinRequestsOpen = false);
              }
            },

            // DENY HANDLER
            onDeny: (req) {
              context.read<RoomBloc>().add(
                DenyRejoinEvent(roomId: manager.roomData!.id, requestMap: req),
              );
            },
          ),
        ],
        // --- NEW: REPORT DIALOG ---
        if (_isReportOpen &&
            manager.isExpanded &&
            manager.roomData != null) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _isReportOpen = false),
              child: Container(color: Colors.black.withOpacity(0.7)),
            ),
          ),
          ReportDialogStack(
            roomId: manager.roomData!.id,
            onClose: () => setState(() => _isReportOpen = false),
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

        // YOUTUBE REQUESTS SHEET
        if (_isYouTubeRequestsOpen &&
            manager.isExpanded &&
            manager.roomData != null) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _isYouTubeRequestsOpen = false),
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),
          ),
          YouTubeRequestsSheet(
            room: manager.roomData!,
            onClose: () => setState(() => _isYouTubeRequestsOpen = false),
            onAccept: (url, requestMap) {
              setState(() => _isYouTubeRequestsOpen = false);
              context.read<RoomBloc>().add(
                PlayYouTubeVideoEvent(
                  roomId: manager.roomData!.id,
                  videoUrl: url,
                  requestToRemove: requestMap,
                ),
              );
            },
          ),
        ],

        // YOUTUBE INPUT DIALOG
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
                context.read<RoomBloc>().add(
                  PlayYouTubeVideoEvent(roomId: roomId, videoUrl: url),
                );
              } else {
                if (currentUser != null) {
                  context.read<RoomBloc>().add(
                    RequestYouTubeAccessEvent(
                      roomId: roomId,
                      userId: currentUser.uid,
                      videoUrl: url,
                    ),
                  );
                }
              }
            },
          ),
        ],

        // PARTICIPANT OPTIONS
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
            
            // --- CRITICAL FIX: BAN LOGIC HERE ---
            onKickUser: (userId) {
              debugPrint("Processing BAN for userId: $userId");
              // This triggers the Bloc Event from the Overlay's valid context
              context.read<RoomBloc>().add(
                KickUserEvent(roomId: manager.roomData!.id, userId: userId),
              );
            },
            // -------------------------------------
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

// ==========================================
//  HELPER STACK WIDGETS
// ==========================================

// --- 1. User Management Sheet (Mutes/Bans) ---
class UserManagementSheetStack extends StatelessWidget {
  final bool isBanning;
  final List<RoomMember> members;
  final String roomId;
  final VoidCallback onClose;
  final RoomGlobalManager manager;

  const UserManagementSheetStack({
    super.key,
    required this.isBanning,
    required this.members,
    required this.roomId,
    required this.onClose,
    required this.manager,
  });

  @override
  Widget build(BuildContext context) {
    // Filter out the host
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    final guests = members.where((m) => m.uid != currentUserUid).toList();

    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: const Color(0xFF1E1E1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40),
                  Text(
                    isBanning ? "Ban Users" : "Manage Audio",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: onClose,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (guests.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    "No guests in the room.",
                    style: TextStyle(color: Colors.white54),
                  ),
                ),

              // LIST
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: guests.length,
                  itemBuilder: (context, index) {
                    final member = guests[index];
                    return _UserAudioTile(
                      key: ValueKey(
                        member.uid,
                      ), // Critical: Keeps state logic attached to the user
                      member: member,
                      manager: manager,
                      isBanning: isBanning,
                      roomId: roomId,
                      onCloseSheet: onClose,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- PRIVATE HELPER: AUDIO TILE ---
class _UserAudioTile extends StatefulWidget {
  final RoomMember member;
  final RoomGlobalManager manager;
  final bool isBanning;
  final String roomId;
  final VoidCallback onCloseSheet;

  const _UserAudioTile({
    super.key,
    required this.member,
    required this.manager,
    required this.isBanning,
    required this.roomId,
    required this.onCloseSheet,
  });

  @override
  State<_UserAudioTile> createState() => _UserAudioTileState();
}

class _UserAudioTileState extends State<_UserAudioTile> {
  Participant? _participant;

  @override
  void initState() {
    super.initState();
    _findParticipant();
  }

  @override
  void didUpdateWidget(covariant _UserAudioTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-check on every build, because the Room object or participants map changes
    _findParticipant();
  }

  @override
  void dispose() {
    _participant?.removeListener(_onParticipantChanged);
    super.dispose();
  }

  void _findParticipant() {
    final room = widget.manager.livekitRoom;
    if (room == null) return;

    // 1. DIRECT LOOKUP in Remote Participants
    // We search values because keys are SIDs, not always UIDs
    Participant? found;
    try {
      found = room.remoteParticipants.values.firstWhere(
        (p) => p.identity == widget.member.uid,
      );
    } catch (_) {
      // Not in remote participants
    }

    // 2. Fallback: Check Local (Shouldn't happen due to filter, but safe)
    if (found == null && room.localParticipant?.identity == widget.member.uid) {
      found = room.localParticipant;
    }

    // 3. Listener Management
    if (found != _participant) {
      // If we switched to a new object (or went from null to found)
      if (_participant != null) {
        _participant!.removeListener(_onParticipantChanged);
      }
      _participant = found;
      if (_participant != null) {
        _participant!.addListener(_onParticipantChanged);
      }

      if (mounted) setState(() {});
    }
  }

  void _onParticipantChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // 1. Get Live Data directly from Participant object
    bool isMicOn = false;
    bool isSpeaking = false;
    bool isConnected = _participant != null;

    if (_participant != null) {
      isMicOn = _participant!.isMicrophoneEnabled();
      isSpeaking = _participant!.isSpeaking;
    }

    String statusText;
    Color statusColor;

    if (!isConnected) {
      statusText = "Not Connected";
      statusColor = Colors.grey;
    } else if (isSpeaking) {
      statusText = "Speaking...";
      statusColor = Colors.greenAccent;
    } else if (isMicOn) {
      statusText = "Mic On";
      statusColor = Colors.green;
    } else {
      statusText = "Muted";
      statusColor = Colors.redAccent;
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
            (widget.member.avatarUrl != null &&
                widget.member.avatarUrl!.isNotEmpty)
            ? NetworkImage(widget.member.avatarUrl!)
            : null,
        backgroundColor: Colors.grey[800],
        child:
            (widget.member.avatarUrl == null ||
                widget.member.avatarUrl!.isEmpty)
            ? const Icon(Icons.person, color: Colors.white70)
            : null,
      ),
      title: Text(
        widget.member.displayName ?? "Guest",
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: !widget.isBanning
          ? Row(
              children: [
                Icon(Icons.circle, size: 8, color: statusColor),
                const SizedBox(width: 6),
                Text(
                  statusText,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            )
          : null,
      trailing: IconButton(
        icon: Icon(
          widget.isBanning
              ? Icons.gavel
              : (isMicOn ? Icons.mic : Icons.mic_off),
          color: widget.isBanning
              ? Colors.redAccent
              : (isMicOn ? Colors.green : Colors.grey),
        ),
        onPressed: () {
          if (widget.isBanning) {
            context.read<RoomBloc>().add(
              KickUserEvent(roomId: widget.roomId, userId: widget.member.uid),
            );
            widget.onCloseSheet();
          } else {
            // Mute Logic - Visual only for now as discussed
            if (isConnected)
              debugPrint("Mute toggled for ${widget.member.displayName}");
          }
        },
      ),
    );
  }
}

// --- 2. Edit Room Dialog (Stack Version) ---
class EditRoomDialogStack extends StatefulWidget {
  final ChatRoom room;
  final VoidCallback onClose;
  const EditRoomDialogStack({
    super.key,
    required this.room,
    required this.onClose,
  });

  @override
  State<EditRoomDialogStack> createState() => _EditRoomDialogStackState();
}

class _EditRoomDialogStackState extends State<EditRoomDialogStack> {
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.room.title);
    _descCtrl = TextEditingController(text: widget.room.description);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        elevation: 10,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Edit Room",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _titleCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Topic",
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Description",
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: widget.onClose,
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      context.read<RoomBloc>().add(
                        UpdateRoomInfoEvent(
                          roomId: widget.room.id,
                          title: _titleCtrl.text,
                          description: _descCtrl.text,
                        ),
                      );
                      widget.onClose();
                    },
                    child: const Text("Save"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 3. Report Dialog (Stack Version) ---
class ReportDialogStack extends StatefulWidget {
  final String roomId;
  final VoidCallback onClose;
  const ReportDialogStack({
    super.key,
    required this.roomId,
    required this.onClose,
  });

  @override
  State<ReportDialogStack> createState() => _ReportDialogStackState();
}

class _ReportDialogStackState extends State<ReportDialogStack> {
  final TextEditingController _reasonCtrl = TextEditingController();
  String _selectedReason = "Spam";
  final List<String> _reasons = [
    "Spam",
    "Abusive Language",
    "Inappropriate Content",
    "Other",
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        elevation: 10,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Report Room",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  "Reason:",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),

                // FIXED: Use Radio Buttons instead of Dropdown to avoid Navigator crashes in Overlay
                ..._reasons.map(
                  (r) => RadioListTile<String>(
                    title: Text(
                      r,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    value: r,
                    groupValue: _selectedReason,
                    activeColor: Colors.redAccent,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    onChanged: (val) => setState(() => _selectedReason = val!),
                  ),
                ),

                const SizedBox(height: 10),
                TextField(
                  controller: _reasonCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "Description (Optional)",
                    hintStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: widget.onClose,
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      onPressed: () {
                        final reporterId =
                            FirebaseAuth.instance.currentUser?.uid ?? "anon";
                        context.read<RoomBloc>().add(
                          ReportRoomEvent(
                            roomId: widget.roomId,
                            reporterId: reporterId,
                            reason: _selectedReason,
                            description: _reasonCtrl.text,
                          ),
                        );
                        widget.onClose();
                      },
                      child: const Text("Report"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
