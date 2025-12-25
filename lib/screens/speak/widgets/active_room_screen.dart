import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livekit_client/livekit_client.dart';

// Your App Imports
import 'package:linguaflow/blocs/speak/speak_bloc.dart';
import 'package:linguaflow/blocs/speak/speak_event.dart';
import 'package:linguaflow/models/speak/speak_models.dart';
import 'package:linguaflow/screens/speak/widgets/sheets/room_chat_sheet.dart';
import 'package:linguaflow/services/speak/chat_service.dart'; // Import ChatService

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

  @override
  void initState() {
    super.initState();
    _refreshParticipants();
    _setUpListeners();
    _setupChatListener();
  }

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
        if (mounted && !_isLeaving) {
          Navigator.pop(context);
        }
      });
  }

  // --- 1. CHAT LISTENER LOGIC ---
  void _setupChatListener() {
    // Initialize last read count to current history so we don't show badges for old messages immediately
    _lastReadCount = _chatService.currentMessages.length;

    _chatSubscription = _chatService.messagesStream.listen((messages) {
      if (!mounted) return;

      if (_isChatOpen) {
        // If chat is open, we are reading them instantly.
        _lastReadCount = messages.length;
        setState(() => _unreadCount = 0);
      } else {
        // If chat is closed, calculate how many are new since we last looked.
        // We ensure it doesn't go negative.
        final diff = messages.length - _lastReadCount;
        setState(() {
          _unreadCount = diff > 0 ? diff : 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _listener?.dispose();
    _chatSubscription?.cancel(); // Cancel stream
    super.dispose();
  }

  Future<void> _toggleMic() async {
    final local = widget.livekitRoom.localParticipant;
    if (local != null) {
      final isEnabled = local.isMicrophoneEnabled();
      await local.setMicrophoneEnabled(!isEnabled);
    }
  }

  Future<void> _toggleCamera() async {
    final local = widget.livekitRoom.localParticipant;
    if (local != null) {
      final isEnabled = local.isCameraEnabled();
      try {
        await local.setCameraEnabled(!isEnabled);
      } catch (e) {
        debugPrint("Camera toggle error: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not access camera")),
        );
      }
    }
  }

  void _leaveRoom(BuildContext context) async {
    if (_isLeaving) return;
    setState(() => _isLeaving = true);
    await widget.livekitRoom.disconnect();
    if (mounted) {
      context.read<SpeakBloc>().add(LeaveRoomEvent());
      Navigator.of(context).pop();
    }
  }

  // --- 2. OPEN CHAT LOGIC ---
  void _openChat() async {
    // Mark as open and clear badge
    setState(() {
      _isChatOpen = true;
      _unreadCount = 0;
      // Sync read count to current total
      _lastReadCount = _chatService.currentMessages.length;
    });

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoomChatSheet(room: widget.livekitRoom),
    );

    // When sheet closes:
    if (mounted) {
      setState(() {
        _isChatOpen = false;
        // Sync again in case messages arrived while closing animation played
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
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // GRID
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
                                return ParticipantTile(
                                  participant: _participants[index],
                                );
                              },
                            ),
                    ),
            ),

            // CONTROLS
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
                  // 1. Mic
                  _ControlIcon(
                    icon: isMicEnabled ? Icons.mic : Icons.mic_off,
                    color: isMicEnabled ? theme.primaryColor : Colors.red,
                    label: isMicEnabled ? "Mute" : "Unmute",
                    onTap: _toggleMic,
                  ),

                  // 2. Camera
                  _ControlIcon(
                    icon: isCamEnabled ? Icons.videocam : Icons.videocam_off,
                    color: isCamEnabled ? theme.primaryColor : Colors.grey,
                    label: "Camera",
                    onTap: _toggleCamera,
                  ),

                  // 3. Chat (With Badge)
                  _ControlIcon(
                    icon: Icons.chat_bubble_outline,
                    color: theme.iconTheme.color,
                    label: "Chat",
                    onTap: _openChat, // Use the new method
                    badgeCount: _unreadCount, // Pass the count
                  ),

                  // 4. Leave
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

// =============================================================================
// HELPER WIDGETS
// =============================================================================

class _ControlIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  final int badgeCount; // Added Badge Count

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
            // Icon + Badge Stack
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

class ParticipantTile extends StatelessWidget {
  final Participant participant;

  const ParticipantTile({super.key, required this.participant});

  @override
  Widget build(BuildContext context) {
    TrackPublication? videoPub;
    if (participant.videoTrackPublications.isNotEmpty) {
      videoPub = participant.videoTrackPublications.first;
    }

    final name = participant.name.isNotEmpty
        ? participant.name
        : participant.identity;
    final isMe = participant is LocalParticipant;
    final isMicOn = participant.isMicrophoneEnabled();
    final isSpeaking = participant.isSpeaking;

    Color borderColor = Colors.transparent;
    double borderWidth = 0;

    if (isSpeaking) {
      borderColor = Colors.greenAccent;
      borderWidth = 3.0;
    } else if (isMe) {
      borderColor = Colors.blueAccent.withOpacity(0.5);
      borderWidth = 2.0;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            if (videoPub != null &&
                videoPub.subscribed &&
                videoPub.track != null)
              VideoTrackRenderer(
                videoPub.track as VideoTrack,
                fit: VideoViewFit.cover,
              )
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person, color: Colors.white24, size: 30),
                    const SizedBox(height: 4),
                    Text(
                      name.length > 2
                          ? name.substring(0, 2).toUpperCase()
                          : name,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isMe ? "You" : name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      isMicOn ? Icons.mic : Icons.mic_off,
                      size: 12,
                      color: isMicOn ? Colors.greenAccent : Colors.redAccent,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}