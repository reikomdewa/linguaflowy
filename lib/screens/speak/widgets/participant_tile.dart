import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

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
        borderColor = Colors.blueAccent.withValues(alpha: 0.5);
        borderWidth = 2.0;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: isFullScreen ? null : BorderRadius.circular(12),
        border: isFullScreen
            ? null
            : Border.all(color: borderColor, width: borderWidth),
      ),
      child: ClipRRect(
        borderRadius: isFullScreen
            ? BorderRadius.circular(0)
            : BorderRadius.circular(10),
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
                        size: isFullScreen
                            ? 80
                            : 30, // Bigger icon in full screen
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
                      ),
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
                          fontWeight: isFullScreen
                              ? FontWeight.bold
                              : FontWeight.normal,
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
