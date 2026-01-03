import 'package:flutter/material.dart';
import 'package:linguaflow/screens/speak/active_screen/managers/room_global_manager.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:linguaflow/models/speak/room_member.dart';

class ParticipantTile extends StatefulWidget {
  final Participant participant;
  final bool isFullScreen;
  final BoxFit fit;
  final VoidCallback? onTap;

  const ParticipantTile({
    super.key,
    required this.participant,
    this.isFullScreen = false,
    this.fit = BoxFit.cover,
    this.onTap,
  });

  @override
  State<ParticipantTile> createState() => _ParticipantTileState();
}

class _ParticipantTileState extends State<ParticipantTile> {
  @override
  void initState() {
    super.initState();
    // 1. LISTEN TO CHANGES
    // This triggers a rebuild whenever the participant's audio/video/connection state changes
    widget.participant.addListener(_onParticipantChanged);
  }

  @override
  void didUpdateWidget(covariant ParticipantTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the participant object itself changes (rare, but possible in grids), switch listeners
    if (oldWidget.participant != widget.participant) {
      oldWidget.participant.removeListener(_onParticipantChanged);
      widget.participant.addListener(_onParticipantChanged);
    }
  }

  @override
  void dispose() {
    // 2. CLEANUP
    widget.participant.removeListener(_onParticipantChanged);
    super.dispose();
  }

  void _onParticipantChanged() {
    // 3. REBUILD UI ON CHANGE
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomData = RoomGlobalManager().roomData;
    final participant = widget.participant; // Use the widget's participant

    // --- 1. RESOLVE USER DATA ---
    String displayName = "";
    String? avatarUrl;

    if (roomData != null) {
      if (participant.identity == roomData.hostId) {
        displayName = roomData.hostName ?? "Host";
        avatarUrl = roomData.hostAvatarUrl;
      } else if (roomData.members.isNotEmpty) {
        try {
          final member = roomData.members.firstWhere(
            (m) => m.uid == participant.identity,
          );
          displayName = member.displayName ?? "Member";
          avatarUrl = member.avatarUrl;
        } catch (_) {}
      }
    }

    if (displayName.isEmpty || displayName == "Guest") {
      displayName = participant.name.isNotEmpty
          ? participant.name
          : (participant.identity);
    }

    if (participant is LocalParticipant) {
      displayName = "$displayName (You)";
    }

    // --- 2. VIDEO STATE ---
    TrackPublication? videoPub;
    // Check if there is a video track
    if (participant.videoTrackPublications.isNotEmpty) {
      videoPub = participant.videoTrackPublications.first;
    }

    // Determine if video should be shown
    final isVideoActive =
        videoPub != null &&
        videoPub.subscribed &&
        videoPub.track != null &&
        !videoPub.muted;

    final isMicOn = participant.isMicrophoneEnabled();
    final isSpeaking = participant.isSpeaking;

    // --- 3. BORDER LOGIC ---
    Color borderColor = Colors.transparent;
    double borderWidth = 0;

    if (!widget.isFullScreen) {
      if (isSpeaking) {
        borderColor = Colors.greenAccent;
        borderWidth = 3.0;
      } else if (participant is LocalParticipant) {
        borderColor = Colors.blueAccent.withOpacity(0.5);
        borderWidth = 2.0;
      }
    }

    final videoViewFit = widget.fit == BoxFit.contain
        ? VideoViewFit.contain
        : VideoViewFit.cover;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: widget.isFullScreen ? null : BorderRadius.circular(12),
        border: widget.isFullScreen
            ? null
            : Border.all(color: borderColor, width: borderWidth),
      ),
      child: ClipRRect(
        borderRadius: widget.isFullScreen
            ? BorderRadius.circular(0)
            : BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // LAYER A: VIDEO / AVATAR
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
                          radius: widget.isFullScreen ? 60 : 25,
                          backgroundColor: Colors.grey[800],
                          backgroundImage: NetworkImage(avatarUrl),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person,
                              color: Colors.white24,
                              size: widget.isFullScreen ? 80 : 30,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              displayName.isNotEmpty
                                  ? displayName.substring(0, 1).toUpperCase()
                                  : "?",
                              style: TextStyle(
                                color: Colors.white54,
                                fontWeight: FontWeight.bold,
                                fontSize: widget.isFullScreen ? 30 : 14,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

            // LAYER B: STATUS BAR (Name & Mic)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black54,
                padding: EdgeInsets.symmetric(
                  horizontal: widget.isFullScreen ? 20 : 6,
                  vertical: widget.isFullScreen ? 20 : 4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: widget.isFullScreen ? 18 : 10,
                          fontWeight: widget.isFullScreen
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      isMicOn ? Icons.mic : Icons.mic_off,
                      size: widget.isFullScreen ? 24 : 12,
                      color: isMicOn ? Colors.greenAccent : Colors.redAccent,
                    ),
                  ],
                ),
              ),
            ),

            // LAYER C: TOUCH DETECTOR
            // Only add InkWell if onTap is provided (usually in grid view)
            if (widget.onTap != null)
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onTap,
                    splashColor: Colors.white.withOpacity(0.1),
                    highlightColor: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}