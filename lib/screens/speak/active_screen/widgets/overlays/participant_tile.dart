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
  // Listen to Manager to catch Pause/Unpause events immediately
  final RoomGlobalManager _manager = RoomGlobalManager();

  @override
  void initState() {
    super.initState();
    widget.participant.addListener(_onParticipantChanged);
    _manager.addListener(_onManagerChanged);
  }

  @override
  void didUpdateWidget(covariant ParticipantTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.participant != widget.participant) {
      oldWidget.participant.removeListener(_onParticipantChanged);
      widget.participant.addListener(_onParticipantChanged);
    }
  }

  @override
  void dispose() {
    widget.participant.removeListener(_onParticipantChanged);
    _manager.removeListener(_onManagerChanged);
    super.dispose();
  }

  void _onParticipantChanged() {
    if (mounted) setState(() {});
  }

  void _onManagerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final roomData = _manager.roomData;
    final participant = widget.participant;

    // --- 1. ROBUST HOST CHECK ---
    bool isHost = false;
    RoomMember? matchedMember;

    if (roomData != null) {
      // Strategy A: Direct UID Match (Correct)
      if (participant.identity == roomData.hostId) {
        isHost = true;
      }
      // Strategy B: Lookup Member to check ID
      else if (roomData.members.isNotEmpty) {
        try {
          // Try finding by UID
          matchedMember = roomData.members.firstWhere(
            (m) => m.uid == participant.identity,
            orElse: () => roomData.members.firstWhere(
              // Fallback: Try finding by Display Name (Legacy/ID Mismatch Fix)
              (m) =>
                  m.displayName == participant.identity ||
                  m.displayName == participant.name,
            ),
          );

          if (matchedMember != null && matchedMember.uid == roomData.hostId) {
            isHost = true;
          }
        } catch (_) {}
      }
    }

    // --- 2. PAUSE STATE ---
    final bool isRoomPaused = roomData?.isPrivate ?? false;
    final bool showPauseOverlay = isRoomPaused && isHost;

    // --- 3. RESOLVE DISPLAY DATA ---
    String displayName = "";
    String? avatarUrl;

    if (roomData != null) {
      if (isHost) {
        displayName = roomData.hostName ?? "Host";
        avatarUrl = roomData.hostAvatarUrl;
      } else if (matchedMember != null) {
        displayName = matchedMember.displayName ?? "Member";
        avatarUrl = matchedMember.avatarUrl;
      }
    }

    // Fallbacks
    if (displayName.isEmpty || displayName == "Guest") {
      displayName = participant.name.isNotEmpty
          ? participant.name
          : participant.identity;
    }
    if (participant is LocalParticipant) {
      displayName = "$displayName (You)";
    }

    // --- 4. VIDEO STATE ---
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

    // --- 5. SAFE AREA ---
    final double topBadgePadding = widget.isFullScreen
        ? MediaQuery.of(context).padding.top + 12
        : 6.0;
    final double leftBadgePadding = widget.isFullScreen ? 16.0 : 6.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: widget.isFullScreen ? null : BorderRadius.circular(12),
        border: widget.isFullScreen
            ? null
            : Border.all(
                color: participant.isSpeaking
                    ? Colors.greenAccent
                    : Colors.transparent,
                width: participant.isSpeaking ? 3 : 0,
              ),
      ),
      child: ClipRRect(
        borderRadius: widget.isFullScreen
            ? BorderRadius.zero
            : BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // A. VIDEO / AVATAR
            if (isVideoActive)
              VideoTrackRenderer(
                videoPub.track as VideoTrack,
                fit: widget.fit == BoxFit.contain
                    ? VideoViewFit.contain
                    : VideoViewFit.cover,
              )
            else
              Container(
                color: Colors.grey[900],
                child: Center(
                  child: avatarUrl != null
                      ? CircleAvatar(
                          radius: widget.isFullScreen ? 60 : 25,
                          backgroundImage: NetworkImage(avatarUrl),
                        )
                      : const Icon(
                          Icons.person,
                          color: Colors.white24,
                          size: 40,
                        ),
                ),
              ),

            // B. PAUSE OVERLAY (Host Only)
            if (showPauseOverlay)
              Container(
                color: Colors.black.withOpacity(0.75),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.pause_circle_filled_rounded,
                        color: Colors.amber,
                        size: widget.isFullScreen ? 60 : 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "HOST PAUSED",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: widget.isFullScreen ? 18 : 11,
                          letterSpacing: 1.2,
                          shadows: const [
                            Shadow(
                              blurRadius: 4,
                              color: Colors.black,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // C. NAME BAR
            Positioned(
              bottom: widget.isFullScreen
                  ? 50
                  : 5, // Moved up slightly for a better look
              left: 5, // Anchored to left
              // REMOVED: right: 0 (This stops it from stretching full width)
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4), // Rounded corners
                ),
                // Constrain width so long names still truncate with ellipsis
                constraints: BoxConstraints(
                  maxWidth: widget.isFullScreen
                      ? MediaQuery.of(context).size.width * 0.7
                      : 100,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min, // Shrink wrap the row
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),

                    // If you want the mic icon back, uncomment this:
                    const SizedBox(width: 4),
                    if (widget.isFullScreen)
                      Icon(
                        isMicOn ? Icons.mic : Icons.mic_off,
                        size: 14,
                        color: isMicOn ? Colors.greenAccent : Colors.redAccent,
                      ),
                  ],
                ),
              ),
            ),
            if (!widget.isFullScreen)
              Positioned(
                right: 2,
                top: 2,
                child: Icon(
                  isMicOn ? Icons.mic : Icons.mic_off,
                  size: 16,
                  color: isMicOn ? Colors.green : Colors.red,
                ),
              ),

            // D. HOST BADGE
            if (isHost)
              Positioned(
                top: topBadgePadding,
                left: leftBadgePadding,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                    // boxShadow: [
                    //   BoxShadow(
                    //     color: Colors.black.withOpacity(0.4),
                    //     blurRadius: 4,
                    //     offset: const Offset(0, 2),
                    //   ),
                    // ],
                  ),
                  child: const Text(
                    "HOST",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // E. TOUCH
            if (widget.onTap != null)
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(onTap: widget.onTap),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
