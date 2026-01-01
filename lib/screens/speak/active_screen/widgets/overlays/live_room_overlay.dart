import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:linguaflow/core/globals.dart';
import 'package:linguaflow/models/speak/room_member.dart';
import 'package:linguaflow/screens/speak/active_screen/managers/room_global_manager.dart';
import 'package:linguaflow/screens/speak/active_screen/widgets/overlays/morphing_room_card.dart';
import 'package:linguaflow/screens/speak/active_screen/widgets/overlays/room_sheets.dart';
import 'package:livekit_client/livekit_client.dart';

// INTERNAL IMPORTS (New Paths)

import 'package:linguaflow/screens/speak/widgets/sheets/room_chat_sheet.dart';
import 'package:linguaflow/screens/speak/widgets/full_screen_participant.dart';
import 'package:linguaflow/services/speak/chat_service.dart';

// GLOBAL

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
  bool _isMenuOpen = false;
  bool _isLeaveConfirmOpen = false;

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
      // Reset UI
      if (_isChatOpen) setState(() => _isChatOpen = false);
      if (_isMenuOpen) setState(() => _isMenuOpen = false);
      if (_isLeaveConfirmOpen) setState(() => _isLeaveConfirmOpen = false);
      if (_selectedParticipant != null)
        setState(() => _selectedParticipant = null);
      if (_fullScreenParticipant != null)
        setState(() => _fullScreenParticipant = null);
      _hasSeenSelfInFirestore = false;
    }
    if (mounted) setState(() {});
  }

  void _setupFirestoreListeners(String roomId) {
    _roomDocSubscription?.cancel();
    final docRef = FirebaseFirestore.instance.collection('rooms').doc(roomId);

    _roomDocSubscription = docRef.snapshots().listen((snapshot) {
      // 1. HANDLE ROOM DELETION
      if (!snapshot.exists || !mounted) {
        RoomGlobalManager().leaveRoom();
        return;
      }

      final data = snapshot.data();
      if (data == null) return;

      final manager = RoomGlobalManager();

      // 2. SYNC MEMBERS (Fixes "Guest" name issue)
      // We must update the local manager state so ParticipantTile can find names.
      if (data.containsKey('members')) {
        try {
          final List<dynamic> rawMembers = data['members'] ?? [];
          final List<RoomMember> parsedMembers = rawMembers
              .map((m) => RoomMember.fromMap(m as Map<String, dynamic>))
              .toList();

          manager.updateMembers(parsedMembers);
        } catch (e) {
          debugPrint("Error parsing members: $e");
        }
      }

      final currentUser = FirebaseAuth.instance.currentUser;

      // 3. KICK LOGIC (With Safety Flag)
      if (currentUser != null) {
        final members = List.from(data['members'] ?? []);
        final myUid = currentUser.uid;

        // Check if I exist in the member list
        final amIInList = members.any((m) {
          if (m is Map) return m['uid'] == myUid;
          return false;
        });

        final amIHost = manager.roomData?.hostId == myUid;

        // SAFETY FLAG: Only mark as "Seen" if we are actually present.
        // This prevents the app from kicking us during the 1-second delay
        // between joining LiveKit and Firestore updating.
        if (amIInList || amIHost) {
          _hasSeenSelfInFirestore = true;
        }

        // EXECUTE KICK: Only if we were previously seen, and now we are gone.
        if (_hasSeenSelfInFirestore &&
            !amIInList &&
            !amIHost &&
            manager.isActive) {
          manager.leaveRoom();

          // Use global navigator key to show snackbar safely over the overlay
          if (navigatorKey.currentContext != null) {
            ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
              const SnackBar(
                content: Text("You have been kicked from the room."),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      // 4. SPOTLIGHT LOGIC
      final spotlightId = data['spotlightedUserId'] as String?;
      if (spotlightId != _currentSpotlightId) {
        setState(() => _currentSpotlightId = spotlightId);

        if (spotlightId != null) {
          try {
            final p = _participants.firstWhere(
              (p) => p.identity == spotlightId,
            );
            setState(() => _fullScreenParticipant = p);
          } catch (_) {}
        } else {
          // If spotlight removed, close fullscreen
          if (_fullScreenParticipant != null) {
            setState(() => _fullScreenParticipant = null);
          }
        }
      }
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
      ..on<TrackMutedEvent>((_) => _safeSetState())
      ..on<TrackUnmutedEvent>((_) => _safeSetState())
      ..on<ActiveSpeakersChangedEvent>((_) => _safeSetState())
      ..on<RoomDisconnectedEvent>((_) => RoomGlobalManager().leaveRoom());
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

  void _refreshParticipants() {
    final room = RoomGlobalManager().livekitRoom;
    if (room == null) return;
    setState(() {
      _participants = [
        if (room.localParticipant != null) room.localParticipant!,
        ...room.remoteParticipants.values,
      ];
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
    final manager = RoomGlobalManager();
    final myId = manager.livekitRoom?.localParticipant?.identity;

    if (p.identity == myId) {
      setState(() {
        _fullScreenParticipant = (_fullScreenParticipant == p) ? null : p;
      });
    } else {
      setState(() {
        _selectedParticipant = p;
        _isChatOpen = false;
        _isMenuOpen = false;
      });
    }
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
              child: Container(
                // color: Colors.black.withOpacity(0.8)
              ),
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
                _isMenuOpen = false;
                _isLeaveConfirmOpen = false;
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
                _selectedParticipant = null;
                _isMenuOpen = true;
              });
            },
            onClosePress: () {
              setState(() {
                _isChatOpen = false;
                _isMenuOpen = false;
                _selectedParticipant = null;
                _isLeaveConfirmOpen = true;
              });
            },
            onParticipantTap: _handleParticipantTap,
          ),
        ),

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
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      // color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () =>
                        setState(() => _fullScreenParticipant = null),
                  ),
                ),
              ],
            ),
          ),

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
                    // color: Color(0xFF1E1E1E),
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

        if (_isMenuOpen && manager.isExpanded) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _isMenuOpen = false),
              child: Container(color: Colors.black.withOpacity(0.6)),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              type: MaterialType.transparency,
              child: RoomMenuSheet(
                manager: manager,
                onClose: () => setState(() => _isMenuOpen = false),
                roomData: manager.roomData!,
              ),
            ),
          ),
        ],

        if (_selectedParticipant != null && manager.isExpanded) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _selectedParticipant = null),
              child: Container(color: Colors.black.withOpacity(0.6)),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              type: MaterialType.transparency,
              child: ParticipantOptionsSheet(
                targetParticipant: _selectedParticipant!,
                amIHost:
                    manager.roomData?.hostId ==
                    FirebaseAuth.instance.currentUser?.uid,
                currentSpotlightId: _currentSpotlightId,
                roomData: manager.roomData!,
                onClose: () => setState(() => _selectedParticipant = null),
                onSetFullScreen: () {
                  setState(() {
                    _fullScreenParticipant = _selectedParticipant;
                    _selectedParticipant = null;
                  });
                },
              ),
            ),
          ),
        ],

        if (_isLeaveConfirmOpen && manager.isExpanded) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _isLeaveConfirmOpen = false),
              child: Container(color: Colors.black.withOpacity(0.6)),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: LeaveConfirmDialog(
                roomData: manager.roomData,
                onConfirm: () => manager.leaveRoom(),
                onCancel: () => setState(() => _isLeaveConfirmOpen = false),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
