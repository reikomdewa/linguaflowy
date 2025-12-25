import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/speak/room/room_bloc.dart';
import 'package:linguaflow/blocs/speak/room/room_event.dart' hide RoomEvent;
import 'package:linguaflow/screens/speak/widgets/full_screen_participant.dart';
import 'package:linguaflow/screens/speak/widgets/participant_tile.dart';
import 'package:livekit_client/livekit_client.dart';

import 'package:linguaflow/blocs/speak/speak_bloc.dart';
import 'package:linguaflow/blocs/speak/speak_event.dart';
import 'package:linguaflow/models/speak/speak_models.dart';
import 'package:linguaflow/screens/speak/widgets/sheets/room_chat_sheet.dart';
import 'package:linguaflow/services/speak/chat_service.dart';

class ActiveRoomScreen extends StatefulWidget {
  final ChatRoom roomData;
  final Room livekitRoom;

  const ActiveRoomScreen({
    super.key,
    required this.roomData,
    required this.livekitRoom,
  });

  @override
  State<ActiveRoomScreen> createState() => _ActiveRoomScreenState();
}

class _ActiveRoomScreenState extends State<ActiveRoomScreen> {
  // Room State
  List<Participant> _participants = [];
  EventsListener<RoomEvent>? _listener;
  bool _isLeaving = false;

  // Chat Notification State
  final ChatService _chatService = ChatService();
  StreamSubscription? _chatSubscription;
  int _unreadCount = 0;
  int _lastReadCount = 0;
  bool _isChatOpen = false;

  // Firestore Sync State (Kick + Spotlight)
  StreamSubscription? _roomDocSubscription;
  String? _currentSpotlightId;
  bool _isFullScreenOpen = false;

  // FIX: Safety flag to prevent kicking before data syncs
  bool _hasSyncedMembership = false;

  @override
  void initState() {
    super.initState();
    _refreshParticipants();
    _setUpListeners();
    _setupChatListener();
    _setupFirestoreListeners(); // Single listener for Kick & Spotlight
  }

  // --- 1. LIVEKIT LISTENERS ---
  void _refreshParticipants() {
    if (!mounted || _isLeaving) return;
    setState(() {
      _participants = [
        if (widget.livekitRoom.localParticipant != null)
          widget.livekitRoom.localParticipant!,
        ...widget.livekitRoom.remoteParticipants.values,
      ];
    });
  }

  void _setUpListeners() {
    _listener = widget.livekitRoom.createListener();
    _listener!
      ..on<ParticipantConnectedEvent>((_) => _refreshParticipants())
      ..on<ParticipantDisconnectedEvent>((_) => _refreshParticipants())
      ..on<TrackSubscribedEvent>((_) => setState(() {}))
      ..on<TrackUnsubscribedEvent>((_) => setState(() {}))
      ..on<LocalTrackPublishedEvent>((_) => setState(() {}))
      ..on<LocalTrackUnpublishedEvent>((_) => setState(() {}))
      ..on<TrackMutedEvent>((_) => setState(() {}))
      ..on<TrackUnmutedEvent>((_) => setState(() {}))
      ..on<ActiveSpeakersChangedEvent>((_) => setState(() {}))
      ..on<RoomDisconnectedEvent>((_) {
        if (mounted && !_isLeaving) Navigator.pop(context);
      });
  }

  // --- 2. CHAT LISTENER ---
  void _setupChatListener() {
    _lastReadCount = _chatService.currentMessages.length;
    _chatSubscription = _chatService.messagesStream.listen((messages) {
      if (!mounted) return;
      if (_isChatOpen) {
        _lastReadCount = messages.length;
        setState(() => _unreadCount = 0);
      } else {
        final diff = messages.length - _lastReadCount;
        setState(() => _unreadCount = diff > 0 ? diff : 0);
      }
    });
  }

  // --- 3. FIRESTORE LISTENER (Kick & Spotlight) ---
  void _setupFirestoreListeners() {
    final docRef = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomData.id);

    _roomDocSubscription = docRef.snapshots().listen((snapshot) {
      if (!snapshot.exists || !mounted) {
        // Room deleted? Leave.
        if (!_isLeaving) Navigator.pop(context);
        return;
      }

      final data = snapshot.data();
      if (data == null) return;

      // A. KICK CHECK
      final members = List.from(data['members'] ?? []);
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        final myUid = currentUser.uid;

        final amIInList = members.any((m) => m['uid'] == myUid);
        final amIHost = widget.roomData.hostId == myUid;

        // FIX: Only verify kicking if we have successfully synced AT LEAST ONCE.
        // This prevents the "Race Condition" where you join before Firestore updates.
        if (amIInList || amIHost) {
          _hasSyncedMembership = true;
        }

        // Only kick if:
        // 1. We knew we were in the list before (_hasSyncedMembership)
        // 2. We are NO LONGER in the list (!amIInList)
        // 3. We are not the host
        // 4. We are not already leaving
        if (_hasSyncedMembership && !amIInList && !amIHost && !_isLeaving) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("You have been kicked from the room."),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
          _leaveRoom(context);
          return;
        }
      }

      // B. SPOTLIGHT CHECK
      final spotlightId = data['spotlightedUserId'] as String?;
      if (spotlightId != _currentSpotlightId) {
        _currentSpotlightId = spotlightId;

        if (spotlightId != null) {
          // Open Full Screen
          try {
            final p = _participants.firstWhere(
              (p) => p.identity == spotlightId,
            );
            _openFullScreen(p, isRemoteTriggered: true);
          } catch (_) {}
        } else {
          // Close Full Screen
          if (_isFullScreenOpen) Navigator.pop(context);
        }
      }
    });
  }

  @override
  void dispose() {
    _listener?.dispose();
    _chatSubscription?.cancel();
    _roomDocSubscription?.cancel();
    super.dispose();
  }

  // --- 4. TAP LOGIC & HOST SHEET ---
  void _handleParticipantTap(Participant p) {
    final myId = widget.livekitRoom.localParticipant?.identity;
    final targetId = p.identity;
    final hostId = widget.roomData.hostId;
    final hostName = widget.roomData.hostName;

    final isMe = myId == targetId;
    final amIHost = (myId == hostId) || (myId == hostName);

    if (amIHost) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.grey[900],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Text(
                  targetId ?? "Participant",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const Divider(color: Colors.grey),

                ListTile(
                  leading: const Icon(
                    Icons.fullscreen,
                    color: Colors.blueAccent,
                  ),
                  title: const Text(
                    "Full Screen (Me Only)",
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _openFullScreen(p, isRemoteTriggered: false);
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.star_border, color: Colors.amber),
                  title: Text(
                    _currentSpotlightId == targetId
                        ? "Remove Spotlight"
                        : "Spotlight for Everyone",
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    final isCurrentlySpotlighted =
                        _currentSpotlightId == targetId;
                    context.read<RoomBloc>().add(
                      ToggleSpotlightEvent(
                        roomId: widget.roomData.id,
                        userId: isCurrentlySpotlighted ? null : targetId,
                      ),
                    );
                  },
                ),

                if (!isMe)
                  ListTile(
                    leading: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.redAccent,
                    ),
                    title: const Text(
                      "Kick User",
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _confirmKick(targetId!);
                    },
                  ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      );
    } else if (isMe) {
      _openFullScreen(p, isRemoteTriggered: false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Only the Host can manage participants.")),
      );
    }
  }

  void _confirmKick(String userId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Kick User?"),
        content: const Text("This will remove them from the room."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<RoomBloc>().add(
                KickUserEvent(roomId: widget.roomData.id, userId: userId),
              );
            },
            child: const Text("Kick", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _openFullScreen(Participant p, {required bool isRemoteTriggered}) async {
    if (_isFullScreenOpen) return;
    setState(() => _isFullScreenOpen = true);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenParticipantScreen(participant: p),
      ),
    );

    if (mounted) {
      setState(() => _isFullScreenOpen = false);

      final myId = widget.livekitRoom.localParticipant?.identity;
      final hostId = widget.roomData.hostId;
      final hostName = widget.roomData.hostName;
      final amIHost = (myId == hostId) || (myId == hostName);

      if (amIHost && isRemoteTriggered) {
        context.read<RoomBloc>().add(
          ToggleSpotlightEvent(roomId: widget.roomData.id, userId: null),
        );
      }
    }
  }

  // --- 5. ROOM CONTROLS ---
  Future<void> _toggleMic() async {
    final local = widget.livekitRoom.localParticipant;
    if (local != null) {
      await local.setMicrophoneEnabled(!local.isMicrophoneEnabled());
    }
  }

  Future<void> _toggleCamera() async {
    final local = widget.livekitRoom.localParticipant;
    if (local != null) {
      await local.setCameraEnabled(!local.isCameraEnabled());
    }
  }

  void _leaveRoom(BuildContext context) async {
    if (_isLeaving) return;
    setState(() => _isLeaving = true);
    await widget.livekitRoom.disconnect();
    if (mounted) {
      context.read<RoomBloc>().add(LeaveRoomEvent());
      Navigator.of(context).pop();
    }
  }

  void _openChat() async {
    setState(() {
      _isChatOpen = true;
      _unreadCount = 0;
      _lastReadCount = _chatService.currentMessages.length;
    });

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoomChatSheet(room: widget.livekitRoom),
    );

    if (mounted) {
      setState(() {
        _isChatOpen = false;
        _lastReadCount = _chatService.currentMessages.length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final localP = widget.livekitRoom.localParticipant;
    final isMicEnabled = localP?.isMicrophoneEnabled() ?? false;
    final isCamEnabled = localP?.isCameraEnabled() ?? false;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF1A1A1A)
          : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Column(
          children: [
            Text(
              widget.roomData.title,
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "${_participants.length} / ${widget.roomData.maxMembers} Online",
              style: TextStyle(color: theme.hintColor, fontSize: 12),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => _leaveRoom(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.info_outline), onPressed: () {}),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLeaving
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _participants.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 0.85,
                                  ),
                              itemCount: _participants.length,
                              itemBuilder: (context, index) {
                                final p = _participants[index];
                                return GestureDetector(
                                  onTap: () => _handleParticipantTap(p),
                                  child: ParticipantTile(participant: p),
                                );
                              },
                            ),
                    ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ControlIcon(
                    icon: isMicEnabled ? Icons.mic : Icons.mic_off,
                    color: isMicEnabled ? theme.primaryColor : Colors.red,
                    label: isMicEnabled ? "Mute" : "Unmute",
                    onTap: _toggleMic,
                  ),
                  _ControlIcon(
                    icon: isCamEnabled ? Icons.videocam : Icons.videocam_off,
                    color: isCamEnabled ? theme.primaryColor : Colors.grey,
                    label: "Camera",
                    onTap: _toggleCamera,
                  ),
                  _ControlIcon(
                    icon: Icons.chat_bubble_outline,
                    color: theme.iconTheme.color,
                    label: "Chat",
                    onTap: _openChat,
                    badgeCount: _unreadCount,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.call_end, color: Colors.red),
                      iconSize: 32,
                      onPressed: () => _leaveRoom(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ... FullScreenParticipantScreen, _ControlIcon, ParticipantTile are same as previous ...
// (Include them below this line as before)

class _ControlIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  final int badgeCount;

  const _ControlIcon({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 28, color: color),
                if (badgeCount > 0)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
