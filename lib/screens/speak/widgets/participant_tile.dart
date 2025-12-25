 import 'package:flutter/material.dart';
 import 'package:livekit_client/livekit_client.dart';
 import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// class ParticipantTile extends StatefulWidget {
//   final Participant participant;

//   const ParticipantTile({super.key, required this.participant});

//   @override
//   State<ParticipantTile> createState() => _ParticipantTileState();
// }

// class _ParticipantTileState extends State<ParticipantTile> {
//   bool _isSpeaking = false;
//   bool _isMuted = false;

//   @override
//   void initState() {
//     super.initState();
//     // Initialize state
//     _isMuted = widget.participant.isMuted;
//     _isSpeaking = widget.participant.isSpeaking;

//     // Listen to changes (Mute/Speak/Disconnect)
//     widget.participant.addListener(_onParticipantChanged);
//   }

//   @override
//   void dispose() {
//     widget.participant.removeListener(_onParticipantChanged);
//     super.dispose();
//   }

//   void _onParticipantChanged() {
//     if (mounted) {
//       setState(() {
//         _isMuted = widget.participant.isMuted;
//         _isSpeaking = widget.participant.isSpeaking;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
    
//     // Free4Talk Style: A card that glows when speaking
//     return AnimatedContainer(
//       duration: const Duration(milliseconds: 300),
//       decoration: BoxDecoration(
//         color: theme.cardColor,
//         borderRadius: BorderRadius.circular(12),
//         border: _isSpeaking 
//             ? Border.all(color: Colors.greenAccent, width: 3) // Speaking Glow
//             : Border.all(color: Colors.transparent, width: 3),
//         boxShadow: _isSpeaking
//             ? [BoxShadow(color: Colors.greenAccent.withOpacity(0.4), blurRadius: 12)]
//             : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
//       ),
//       child: Stack(
//         children: [
//           // 1. Center Avatar & Name
//           Center(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 CircleAvatar(
//                   radius: 30,
//                   // Use participant metadata or name to generate avatar/initials
//                   backgroundColor: theme.primaryColor.withOpacity(0.2),
//                   backgroundImage: widget.participant.metadata != null 
//                       ? NetworkImage(widget.participant.metadata!) // Assuming you pass avatar URL in metadata
//                       : null,
//                   child: widget.participant.metadata == null
//                       ? Text(
//                           widget.participant.identity.substring(0, 1).toUpperCase(),
//                           style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.primaryColor),
//                         )
//                       : null,
//                 ),
//                 const SizedBox(height: 8),
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 8.0),
//                   child: Text(
//                     widget.participant.name.isNotEmpty ? widget.participant.name : "User",
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                     style: const TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           // 2. Mute Indicator (Top Right)
//           if (_isMuted)
//             Positioned(
//               top: 8,
//               right: 8,
//               child: Container(
//                 padding: const EdgeInsets.all(4),
//                 decoration: const BoxDecoration(
//                   color: Colors.redAccent,
//                   shape: BoxShape.circle,
//                 ),
//                 child: const Icon(Icons.mic_off, size: 12, color: Colors.white),
//               ),
//             ),
            
//           // 3. Host Indicator (Top Left - Optional)
//           // You'd need to check if widget.participant.permissions.canPublish etc. or metadata
//         ],
//       ),
//     );
//   }
// }




// -----------------------------------------------------------------------------
// PARTICIPANT TILE (Updated for Fixes)
// -----------------------------------------------------------------------------
class ParticipantTile extends StatelessWidget {
  final Participant participant;
  final bool isFullScreen;

  const ParticipantTile({
    super.key,
    required this.participant,
    this.isFullScreen = false,
  });

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

    // FIX 1: Strict check for video active status
    // Must be subscribed AND not muted
    final isVideoActive =
        videoPub != null &&
        videoPub.subscribed &&
        videoPub.track != null &&
        !videoPub.muted; // <-- Crucial check!

    Color borderColor = Colors.transparent;
    double borderWidth = 0;

    if (!isFullScreen) {
      if (isSpeaking) {
        borderColor = Colors.greenAccent;
        borderWidth = 3.0;
      } else if (isMe) {
        borderColor = Colors.blueAccent.withOpacity(0.5);
        borderWidth = 2.0;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: isFullScreen ? null : BorderRadius.circular(12),
        border: isFullScreen ? null : Border.all(color: borderColor, width: borderWidth),
      ),
      child: ClipRRect(
        borderRadius: isFullScreen ? BorderRadius.circular(0) : BorderRadius.circular(10),
        child: Stack(
          children: [
            // LAYER 1: VIDEO or AVATAR
            if (isVideoActive)
              VideoTrackRenderer(
                videoPub.track as VideoTrack,
                // Full screen usually uses 'cover' to fill phone screen
                fit: VideoViewFit.cover, 
              )
            else
              // Fallback to Avatar when camera is off
              Container(
                color: Colors.grey[900], // Dark background for avatar
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person,
                        color: Colors.white24,
                        size: isFullScreen ? 80 : 30, // Bigger icon in full screen
                      ),
                      const SizedBox(height: 10),
                      Text(
                        name.length > 2
                            ? name.substring(0, 2).toUpperCase()
                            : name,
                        style: TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.bold,
                          fontSize: isFullScreen ? 30 : 14, // Bigger font
                        ),
                      )
                    ],
                  ),
                ),
              ),

            // LAYER 2: STATUS BAR
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black54, // Semi-transparent bar
                padding: EdgeInsets.symmetric(
                  horizontal: isFullScreen ? 20 : 6,
                  vertical: isFullScreen ? 20 : 4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isMe ? "You" : name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isFullScreen ? 18 : 10,
                          fontWeight: isFullScreen ? FontWeight.bold : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      isMicOn ? Icons.mic : Icons.mic_off,
                      size: isFullScreen ? 24 : 12,
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