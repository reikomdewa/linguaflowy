import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ParticipantTile extends StatefulWidget {
  final Participant participant;

  const ParticipantTile({super.key, required this.participant});

  @override
  State<ParticipantTile> createState() => _ParticipantTileState();
}

class _ParticipantTileState extends State<ParticipantTile> {
  bool _isSpeaking = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    // Initialize state
    _isMuted = widget.participant.isMuted;
    _isSpeaking = widget.participant.isSpeaking;

    // Listen to changes (Mute/Speak/Disconnect)
    widget.participant.addListener(_onParticipantChanged);
  }

  @override
  void dispose() {
    widget.participant.removeListener(_onParticipantChanged);
    super.dispose();
  }

  void _onParticipantChanged() {
    if (mounted) {
      setState(() {
        _isMuted = widget.participant.isMuted;
        _isSpeaking = widget.participant.isSpeaking;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Free4Talk Style: A card that glows when speaking
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: _isSpeaking 
            ? Border.all(color: Colors.greenAccent, width: 3) // Speaking Glow
            : Border.all(color: Colors.transparent, width: 3),
        boxShadow: _isSpeaking
            ? [BoxShadow(color: Colors.greenAccent.withOpacity(0.4), blurRadius: 12)]
            : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
      ),
      child: Stack(
        children: [
          // 1. Center Avatar & Name
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 30,
                  // Use participant metadata or name to generate avatar/initials
                  backgroundColor: theme.primaryColor.withOpacity(0.2),
                  backgroundImage: widget.participant.metadata != null 
                      ? NetworkImage(widget.participant.metadata!) // Assuming you pass avatar URL in metadata
                      : null,
                  child: widget.participant.metadata == null
                      ? Text(
                          widget.participant.identity.substring(0, 1).toUpperCase(),
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.primaryColor),
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    widget.participant.name.isNotEmpty ? widget.participant.name : "User",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // 2. Mute Indicator (Top Right)
          if (_isMuted)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic_off, size: 12, color: Colors.white),
              ),
            ),
            
          // 3. Host Indicator (Top Left - Optional)
          // You'd need to check if widget.participant.permissions.canPublish etc. or metadata
        ],
      ),
    );
  }
}