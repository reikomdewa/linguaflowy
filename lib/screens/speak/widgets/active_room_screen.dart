import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:linguaflow/screens/speak/widgets/sheets/room_chat_sheet.dart';
import 'package:livekit_client/livekit_client.dart';

// Your App Imports
import 'package:linguaflow/blocs/speak/speak_bloc.dart';
import 'package:linguaflow/blocs/speak/speak_event.dart';
import 'package:linguaflow/models/speak/speak_models.dart';
class ActiveRoomScreen extends StatefulWidget {
  final ChatRoom roomData; // Your custom model
  final Room livekitRoom;  // The actual LiveKit connection

  const ActiveRoomScreen({
    super.key, 
    required this.roomData, 
    required this.livekitRoom
  });

  @override
  State<ActiveRoomScreen> createState() => _ActiveRoomScreenState();
}

class _ActiveRoomScreenState extends State<ActiveRoomScreen> {
  // FIXED: Use 'Participant' to hold both Local and Remote users safely
  List<Participant> _participants = [];
  EventsListener<RoomEvent>? _listener;

  @override
  void initState() {
    super.initState();
    // 1. Initial population of the list
    _refreshParticipants();

    // 2. Setup comprehensive listeners
    _setUpListeners();
  }

  void _refreshParticipants() {
    if (!mounted) return;
    setState(() {
      // Create a new list combining Local + Remotes
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
      // People Joining/Leaving
      ..on<ParticipantConnectedEvent>((_) => _refreshParticipants())
      ..on<ParticipantDisconnectedEvent>((_) => _refreshParticipants())
      
      // Hardware/Track Changes (Camera/Mic Toggles)
      // These are crucial so the UI updates when someone mutes/unmutes!
      ..on<TrackSubscribedEvent>((_) => setState(() {}))
      ..on<TrackUnsubscribedEvent>((_) => setState(() {}))
      ..on<LocalTrackPublishedEvent>((_) => setState(() {}))
      ..on<LocalTrackUnpublishedEvent>((_) => setState(() {}))
      ..on<TrackMutedEvent>((_) => setState(() {}))
      ..on<TrackUnmutedEvent>((_) => setState(() {}))
      
      // Room Lifecycle
      ..on<RoomDisconnectedEvent>((_) {
        if (mounted) Navigator.pop(context);
      });
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    final local = widget.livekitRoom.localParticipant;
    if (local != null) {
      // Check if currently enabled
      final isEnabled = local.isMicrophoneEnabled();
      // Set to opposite
      await local.setMicrophoneEnabled(!isEnabled);
      // State updates automatically via the LocalTrackPublished/Unpublished listener
    }
  }

  void _leaveRoom(BuildContext context) async {
    // 1. Disconnect LiveKit
    await widget.livekitRoom.disconnect();
    
    // 2. Notify Bloc & Navigate
    if (mounted) {
      context.read<SpeakBloc>().add(LeaveRoomEvent());
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Determine mic status for the UI icon
    final isMicEnabled = widget.livekitRoom.localParticipant?.isMicrophoneEnabled() ?? false;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              widget.roomData.title, 
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color, 
                fontSize: 16, 
                fontWeight: FontWeight.bold
              )
            ),
            Text(
              "${_participants.length} / ${widget.roomData.maxMembers} Online", 
              style: TextStyle(color: theme.hintColor, fontSize: 12)
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
            onPressed: () {
              // Show room details dialog
            },
          )
        ],
      ),
      body: Column(
        children: [
          // 1. THE GRID OF SEATS
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _participants.isEmpty 
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, // 3 people per row like Free4Talk
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.85, 
                    ),
                    itemCount: _participants.length,
                    itemBuilder: (context, index) {
                      return ParticipantTile(participant: _participants[index]);
                    },
                  ),
            ),
          ),

          // 2. CONTROL BAR (Footer)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1), 
                  blurRadius: 10, 
                  offset: const Offset(0, -2)
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Toggle Mic
                _ControlIcon(
                  icon: isMicEnabled ? Icons.mic : Icons.mic_off,
                  color: isMicEnabled ? theme.primaryColor : Colors.red,
                  label: isMicEnabled ? "Mute" : "Unmute",
                  onTap: _toggleMic,
                ),

                // Chat
                _ControlIcon(
                  icon: Icons.chat_bubble_outline,
                  color: theme.iconTheme.color,
                  label: "Chat",
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => RoomChatSheet(room: widget.livekitRoom),
                    );
                  },
                ),

                // Leave Button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1), 
                    borderRadius: BorderRadius.circular(16)
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

  const _ControlIcon({required this.icon, required this.label, this.color, required this.onTap});

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
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PARTICIPANT TILE (Renders Video or Avatar)
// -----------------------------------------------------------------------------
class ParticipantTile extends StatelessWidget {
  final Participant participant;

  const ParticipantTile({super.key, required this.participant});

  @override
  Widget build(BuildContext context) {
    TrackPublication? videoPub;
    if (participant.videoTrackPublications.isNotEmpty) {
      videoPub = participant.videoTrackPublications.first;
    }

    final name = participant.name.isNotEmpty ? participant.name : participant.identity;
    final isMe = participant is LocalParticipant;
    final isMicOn = participant.isMicrophoneEnabled();

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
        border: isMe ? Border.all(color: Colors.blueAccent, width: 2) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // LAYER 1: VIDEO or AVATAR
            if (videoPub != null && videoPub.subscribed && videoPub.track != null)
              VideoTrackRenderer(
                videoPub.track as VideoTrack,
                // --- THE FIX IS HERE ---
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
                      name.length > 2 ? name.substring(0, 2).toUpperCase() : name,
                      style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
                    )
                  ],
                ),
              ),

            // LAYER 2: STATUS BAR
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
                        style: const TextStyle(color: Colors.white, fontSize: 10),
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