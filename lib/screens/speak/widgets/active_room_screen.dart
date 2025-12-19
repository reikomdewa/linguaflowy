import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:linguaflow/blocs/speak/speak_bloc.dart';
import 'package:linguaflow/blocs/speak/speak_event.dart';
import 'package:linguaflow/models/speak_models.dart';
import 'package:linguaflow/screens/speak/widgets/participant_tile.dart';
import 'package:linguaflow/screens/speak/widgets/sheets/room_chat_sheet.dart';
import 'package:livekit_client/livekit_client.dart';


class ActiveRoomScreen extends StatefulWidget {
  final ChatRoom roomData; // Our custom model
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
  List<Participant> _participants = [];
  EventsListener<RoomEvent>? _listener;

  @override
  void initState() {
    super.initState();
    // Initial load
    _participants = widget.livekitRoom.remoteParticipants.values.toList();
    if (widget.livekitRoom.localParticipant != null) {
      _participants.add(widget.livekitRoom.localParticipant!);
    }

    // Listen to Room Events (Join/Leave)
    _listener = widget.livekitRoom.createListener();
    _listener!
      ..on<ParticipantConnectedEvent>((e) => _updateParticipants())
      ..on<ParticipantDisconnectedEvent>((e) => _updateParticipants())
      ..on<RoomDisconnectedEvent>((e) {
        if (mounted) Navigator.pop(context);
      });
  }

  void _updateParticipants() {
    if (!mounted) return;
    setState(() {
      _participants = widget.livekitRoom.remoteParticipants.values.toList();
      if (widget.livekitRoom.localParticipant != null) {
        _participants.add(widget.livekitRoom.localParticipant!);
      }
    });
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      // Free4Talk often has a subtle background or image
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text(widget.roomData.title, style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 16, fontWeight: FontWeight.bold)),
            Text("${_participants.length} / ${widget.roomData.maxMembers} Online", style: TextStyle(color: theme.hintColor, fontSize: 12)),
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
          // 1. The Grid of Seats
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, // 3 people per row like Free4Talk
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85, // Slightly taller for name
                ),
                itemCount: _participants.length,
                itemBuilder: (context, index) {
                  return ParticipantTile(participant: _participants[index]);
                },
              ),
            ),
          ),

          // 2. Control Bar (Footer)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Toggle Mic
                _ControlIcon(
                  icon: widget.livekitRoom.localParticipant?.isMuted ?? false 
                      ? Icons.mic_off 
                      : Icons.mic,
                  color: widget.livekitRoom.localParticipant?.isMuted ?? false 
                      ? Colors.red 
                      : theme.primaryColor,
                  label: "Mic",
                  onTap: _toggleMic,
                ),

                // Chat (Opens your existing BottomSheet)
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
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
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

  Future<void> _toggleMic() async {
    final local = widget.livekitRoom.localParticipant;
    if (local != null) {
      final isMuted = local.isMuted;
      await local.setMicrophoneEnabled(isMuted); // Flip state
      setState(() {}); // Refresh UI icon
    }
  }

  void _leaveRoom(BuildContext context) async {
    // 1. Disconnect LiveKit
    await widget.livekitRoom.disconnect();
    
    // 2. Notify Bloc
    if (mounted) {
      context.read<SpeakBloc>().add(RoomLeft());
      Navigator.of(context).pop();
    }
  }
}

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