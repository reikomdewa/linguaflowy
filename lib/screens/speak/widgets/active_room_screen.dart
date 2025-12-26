import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livekit_client/livekit_client.dart';

// BLOC IMPORTS
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/blocs/speak/room/room_bloc.dart';
import 'package:linguaflow/blocs/speak/room/room_event.dart' hide RoomEvent;

// MODELS & SERVICES
import 'package:linguaflow/models/speak/speak_models.dart';
import 'package:linguaflow/models/speak/room_member.dart'; 
import 'package:linguaflow/services/speak/chat_service.dart'; // Public LiveKit Chat
import 'package:linguaflow/services/speak/private_chat_service.dart'; // Private Chat
import 'package:linguaflow/models/private_chat_models.dart'; // Private Chat Models

// WIDGETS & SCREENS
import 'package:linguaflow/screens/speak/widgets/full_screen_participant.dart';
import 'package:linguaflow/screens/speak/widgets/participant_tile.dart';
import 'package:linguaflow/screens/speak/widgets/sheets/room_chat_sheet.dart';
import 'package:linguaflow/screens/inbox/private_chat_screen.dart';
import 'package:linguaflow/screens/inbox/inbox_screen.dart';

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

  // Chat Notification State (LiveKit Public Chat)
  final ChatService _chatService = ChatService();
  StreamSubscription? _chatSubscription;
  int _publicUnreadCount = 0;
  int _lastReadCount = 0;
  bool _isChatOpen = false;

  // Firestore Sync State (Kick + Spotlight)
  StreamSubscription? _roomDocSubscription;
  String? _currentSpotlightId;
  bool _isFullScreenOpen = false;

  // Safety flag
  bool _hasSyncedMembership = false;

  @override
  void initState() {
    super.initState();
    _refreshParticipants();
    _setUpListeners();
    _setupPublicChatListener();
    _setupFirestoreListeners();
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

  // --- 2. PUBLIC CHAT LISTENER ---
  void _setupPublicChatListener() {
    _lastReadCount = _chatService.currentMessages.length;
    _chatSubscription = _chatService.messagesStream.listen((messages) {
      if (!mounted) return;
      if (_isChatOpen) {
        _lastReadCount = messages.length;
        setState(() => _publicUnreadCount = 0);
      } else {
        final diff = messages.length - _lastReadCount;
        setState(() => _publicUnreadCount = diff > 0 ? diff : 0);
      }
    });
  }

  // --- 3. FIRESTORE LISTENER ---
  void _setupFirestoreListeners() {
    final docRef = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomData.id);

    _roomDocSubscription = docRef.snapshots().listen((snapshot) {
      if (!snapshot.exists || !mounted) {
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
        final amIInList = members.any((m) {
          if (m is Map) return m['uid'] == myUid;
          return false;
        });
        
        final amIHost = widget.roomData.hostId == myUid;

        if (amIInList || amIHost) {
          _hasSyncedMembership = true;
        }

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
          try {
            final p = _participants.firstWhere(
              (p) => p.identity == spotlightId,
            );
            _openFullScreen(p, isRemoteTriggered: true);
          } catch (_) {}
        } else {
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

  // --- 4. INTERACTION LOGIC (TAP) ---
  void _handleParticipantTap(Participant p) {
    final myId = widget.livekitRoom.localParticipant?.identity;
    final targetId = p.identity;
    final hostId = widget.roomData.hostId;

    final isMe = myId == targetId;
    final amIHost = myId == hostId;

    if (isMe) {
      _openFullScreen(p, isRemoteTriggered: false);
      return;
    }

    _showParticipantOptionsSheet(
      context, 
      targetParticipant: p, 
      amIHost: amIHost
    );
  }

  void _showParticipantOptionsSheet(BuildContext context, {
    required Participant targetParticipant,
    required bool amIHost,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              
              Text(
                targetParticipant.name.isNotEmpty ? targetParticipant.name : "User",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),
              
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.blueAccent),
                title: const Text("Message Privately"),
                onTap: () {
                  Navigator.pop(context);
                  _initiatePrivateChat(targetParticipant);
                },
              ),

              ListTile(
                leading: const Icon(Icons.fullscreen, color: Colors.grey),
                title: const Text("View Full Screen"),
                onTap: () {
                  Navigator.pop(context);
                  _openFullScreen(targetParticipant, isRemoteTriggered: false);
                },
              ),

              if (amIHost) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.star_border, color: Colors.amber),
                  title: Text(
                    _currentSpotlightId == targetParticipant.identity
                        ? "Remove Spotlight"
                        : "Spotlight for Everyone",
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    final isCurrentlySpotlighted = _currentSpotlightId == targetParticipant.identity;
                    context.read<RoomBloc>().add(
                      ToggleSpotlightEvent(
                        roomId: widget.roomData.id,
                        userId: isCurrentlySpotlighted ? null : targetParticipant.identity,
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                  title: const Text("Kick User", style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmKick(targetParticipant.identity!);
                  },
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // --- 5. PRIVATE CHAT HELPER ---
  Future<void> _initiatePrivateChat(Participant target) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final myUser = authState.user;
    final targetId = target.identity;

    RoomMember? targetMember;
    try {
      targetMember = widget.roomData.members.firstWhere(
        (m) => m.uid == targetId,
      );
    } catch (_) {}

    try {
      final chatId = await PrivateChatService().startChat(
        currentUserId: myUser.id,
        otherUserId: targetId!,
        currentUserName: myUser.displayName,
        otherUserName: targetMember?.displayName ?? target.name,
        currentUserPhoto: myUser.photoUrl,
        otherUserPhoto: targetMember?.avatarUrl,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PrivateChatScreen(
              chatId: chatId,
              otherUserName: targetMember?.displayName ?? target.name,
              otherUserPhoto: targetMember?.avatarUrl,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error starting private chat: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not start chat.")),
        );
      }
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
      final amIHost = myId == hostId;

      if (amIHost && isRemoteTriggered) {
        context.read<RoomBloc>().add(
          ToggleSpotlightEvent(roomId: widget.roomData.id, userId: null),
        );
      }
    }
  }

  // --- 6. ROOM CONTROLS ---
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

  void _openPublicChat() async {
    setState(() {
      _isChatOpen = true;
      _publicUnreadCount = 0;
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

  // ==========================================
  // 7. BUILD
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final localP = widget.livekitRoom.localParticipant;
    final isMicEnabled = localP?.isMicrophoneEnabled() ?? false;
    final isCamEnabled = localP?.isCameraEnabled() ?? false;
    
    // Get Current User for Inbox Stream
    final authState = context.read<AuthBloc>().state;
    final myUser = (authState is AuthAuthenticated) ? authState.user : null;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
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
          // INBOX ICON WITH BADGE (FIXED)
          if (myUser != null)
            StreamBuilder<List<PrivateConversation>>(
              stream: PrivateChatService().getInbox(myUser.id),
              builder: (context, snapshot) {
                int totalUnreadMessages = 0;
                if (snapshot.hasData) {
                  final chats = snapshot.data!;
                  for (var chat in chats) {
                    bool isLastMsgFromMe = chat.lastSenderId == myUser.id;
                    if (!isLastMsgFromMe) {
                      totalUnreadMessages += chat.unreadCount;
                    }
                  }
                }
                return IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const InboxScreen()),
                    );
                  },
                  icon: Badge(
                    isLabelVisible: totalUnreadMessages > 0,
                    label: Text(
                      totalUnreadMessages > 99 ? '99+' : '$totalUnreadMessages',
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.message),
                  ),
                );
              },
            ),
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
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                    label: "Room Chat",
                    onTap: _openPublicChat,
                    badgeCount: _publicUnreadCount,
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
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
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