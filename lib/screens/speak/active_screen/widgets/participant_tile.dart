import 'package:flutter/material.dart';
import 'package:linguaflow/screens/speak/active_screen/managers/room_global_manager.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:linguaflow/models/speak/room_member.dart';

class ParticipantTile extends StatelessWidget {
  final Participant participant;
  final bool isFullScreen;
  final BoxFit fit;

  const ParticipantTile({
    super.key,
    required this.participant,
    this.isFullScreen = false,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final roomData = RoomGlobalManager().roomData;

    // --- 1. RESOLVE USER DATA (NAME & AVATAR) ---
    String displayName = "";
    String? avatarUrl;

    if (roomData != null) {
      // CHECK A: Is this participant the HOST?
      // The host's details are stored in top-level fields, not always in 'members'
      if (participant.identity == roomData.hostId) {
        displayName = roomData.hostName!;
        avatarUrl = roomData.hostAvatarUrl;
      }
      // CHECK B: Is this participant a MEMBER?
      else if (roomData.members.isNotEmpty) {
        try {
          final member = roomData.members.firstWhere(
            (m) => m.uid == participant.identity,
          );
          displayName = member.displayName!;
          avatarUrl = member.avatarUrl;
        } catch (_) {
          // Not found in members list
        }
      }
    }

    // --- 2. FALLBACKS ---
    // If Firestore didn't return a name, use LiveKit name, or ID
    if (displayName.isEmpty || displayName == "Guest") {
      displayName = participant.name.isNotEmpty
          ? participant.name
          : (participant.identity ?? "User");
    }

    // Append "(You)" if it's the local user
    if (participant is LocalParticipant) {
      displayName = "$displayName (You)";
    }

    // --- 3. VIDEO STATE ---
    TrackPublication? videoPub;
    if (participant.videoTrackPublications.isNotEmpty) {
      videoPub = participant.videoTrackPublications.first;
    }

    final isVideoActive =
        videoPub != null &&
        videoPub.subscribed &&
        videoPub.track != null &&
        !videoPub.muted;

    final isMicOn = participant.isMicrophoneEnabled();
    final isSpeaking = participant.isSpeaking;

    // --- 4. BORDER LOGIC ---
    Color borderColor = Colors.transparent;
    double borderWidth = 0;

    if (!isFullScreen) {
      if (isSpeaking) {
        borderColor = Colors.greenAccent;
        borderWidth = 3.0;
      } else if (participant is LocalParticipant) {
        borderColor = Colors.blueAccent.withOpacity(0.5);
        borderWidth = 2.0;
      }
    }

    final videoViewFit = fit == BoxFit.contain
        ? VideoViewFit.contain
        : VideoViewFit.cover;

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
          fit: StackFit.expand,
          children: [
            // LAYER 1: VIDEO or AVATAR
            if (isVideoActive)
              VideoTrackRenderer(
                videoPub.track as VideoTrack,
                fit: videoViewFit,
              )
            else
              Container(
                color: Colors.grey[900],
                child: Center(
                  child: avatarUrl != null && avatarUrl.isNotEmpty
                      ? CircleAvatar(
                          radius: isFullScreen ? 60 : 25,
                          backgroundColor: Colors.grey[800],
                          backgroundImage: NetworkImage(avatarUrl),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person,
                              color: Colors.white24,
                              size: isFullScreen ? 80 : 30,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              displayName.isNotEmpty
                                  ? displayName.substring(0, 1).toUpperCase()
                                  : "?",
                              style: TextStyle(
                                color: Colors.white54,
                                fontWeight: FontWeight.bold,
                                fontSize: isFullScreen ? 30 : 14,
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
                color: Colors.black54,
                padding: EdgeInsets.symmetric(
                  horizontal: isFullScreen ? 20 : 6,
                  vertical: isFullScreen ? 20 : 4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
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
