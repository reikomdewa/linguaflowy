import 'dart:async';
import 'package:flutter/material.dart';
import 'package:linguaflow/screens/speak/active_screen/managers/room_global_manager.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:linguaflow/models/speak/room_member.dart';

class ParticipantTile extends StatefulWidget {
  final Participant participant;
  final bool isFullScreen;
  final BoxFit fit; // This is a standard Flutter BoxFit
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
  final RoomGlobalManager _manager = RoomGlobalManager();
  
  // We track the current video track ID to detect legitimate changes
  String? _currentTrackSid;

  @override
  void initState() {
    super.initState();
    widget.participant.addListener(_onParticipantChanged);
    _manager.addListener(_onManagerChanged);
    
    // Initialize immediately to prevent "Black Flash"
    _updateTrackState();
  }

  @override
  void didUpdateWidget(covariant ParticipantTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.participant != widget.participant) {
      oldWidget.participant.removeListener(_onParticipantChanged);
      widget.participant.addListener(_onParticipantChanged);
      _updateTrackState();
    }
    // Re-evaluate track choice if we enter/exit full screen
    if (oldWidget.isFullScreen != widget.isFullScreen) {
      _updateTrackState();
    }
  }

  @override
  void dispose() {
    widget.participant.removeListener(_onParticipantChanged);
    _manager.removeListener(_onManagerChanged);
    super.dispose();
  }

  void _onParticipantChanged() {
    if (mounted) {
      _updateTrackState();
      setState(() {});
    }
  }

  void _onManagerChanged() {
    if (mounted) setState(() {});
  }

  void _updateTrackState() {
    final pub = _getBestVideoTrack();
    if (pub?.sid != _currentTrackSid) {
      _currentTrackSid = pub?.sid;
      // We don't need to force a setState here if called from build, 
      // but if called from listeners, the setState in _onParticipantChanged handles it.
    }
  }

  /// ROBUST TRACK SELECTION LOGIC
  /// Prioritizes screen share and prevents flickering to camera
  TrackPublication? _getBestVideoTrack() {
    final participant = widget.participant;

    // 1. Try to find a Screen Share track
    try {
      final screenSharePub = participant.videoTrackPublications.firstWhere(
        (pub) => pub.source == TrackSource.screenShareVideo,
      );

      // FIX: If we are in full screen, OR if the track is active, use it.
      // We are more lenient here: even if 'muted' is true momentarily, we stick
      // to the screen share track to avoid the UI flipping back and forth.
      if (widget.isFullScreen || 
         (screenSharePub.subscribed && screenSharePub.track != null)) {
        return screenSharePub;
      }
    } catch (_) {
      // No screen share found
    }

    // 2. Fallback to Camera
    try {
      final cameraPub = participant.videoTrackPublications.firstWhere(
        (pub) => pub.source == TrackSource.camera,
      );
      if (cameraPub.subscribed && !cameraPub.muted) {
        return cameraPub;
      }
    } catch (_) {
      // No camera found
    }

    // 3. Fallback to first available video
    return participant.videoTrackPublications.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final roomData = _manager.roomData;
    final participant = widget.participant;
    final videoPub = _getBestVideoTrack();
    
    // Ensure we have a valid track object before trying to render
    final isVideoActive = videoPub != null && videoPub.track != null;

    // --- LOGIC TO RESOLVE VIDEO FIT ---
    // We must strictly return VideoViewFit, not BoxFit.
    VideoViewFit rendererFit;
    
    if (videoPub?.source == TrackSource.screenShareVideo) {
      // For screen share:
      // - Full Screen: Use contain (so we see the whole screen, e.g. text/code)
      // - Small Tile: Use cover (so it fills the box nicely)
      rendererFit = widget.isFullScreen ? VideoViewFit.contain : VideoViewFit.cover;
    } else {
      // For camera/other:
      // Convert the widget's incoming BoxFit preference to VideoViewFit
      rendererFit = (widget.fit == BoxFit.contain) 
          ? VideoViewFit.contain 
          : VideoViewFit.cover;
    }

    // --- HOST & DISPLAY NAME LOGIC ---
    bool isHost = false;
    RoomMember? matchedMember;

    if (roomData != null) {
      if (participant.identity == roomData.hostId) {
        isHost = true;
      } else if (roomData.members.isNotEmpty) {
        try {
          matchedMember = roomData.members.firstWhere(
            (m) => m.uid == participant.identity || 
                   m.displayName == participant.identity,
          );
          if (matchedMember != null && matchedMember.uid == roomData.hostId) {
            isHost = true;
          }
        } catch (_) {}
      }
    }

    String displayName = matchedMember?.displayName ?? 
        (participant.name.isNotEmpty ? participant.name : participant.identity);
    if (participant is LocalParticipant) displayName += " (You)";
    final String? avatarUrl = matchedMember?.avatarUrl;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: widget.isFullScreen ? null : BorderRadius.circular(12),
        border: (!widget.isFullScreen && participant.isSpeaking)
            ? Border.all(color: Colors.greenAccent, width: 3)
            : null,
      ),
      child: ClipRRect(
        borderRadius: widget.isFullScreen 
            ? BorderRadius.zero 
            : BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // A. VIDEO LAYER
            if (isVideoActive)
              VideoTrackRenderer(
                videoPub!.track as VideoTrack,
                // CRITICAL FIX: Use SID as key.
                // Do NOT use a counter/random key. This keeps the renderer alive
                // even when the parent widget rebuilds.
                key: ValueKey(videoPub.sid),
                fit: rendererFit,
              )
            else
              // B. FALLBACK / AVATAR LAYER
              Container(
                color: Colors.grey[850],
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (avatarUrl != null)
                        CircleAvatar(
                          radius: widget.isFullScreen ? 60 : 25,
                          backgroundImage: NetworkImage(avatarUrl),
                        )
                      else
                        const Icon(
                          Icons.person, 
                          color: Colors.white24, 
                          size: 40
                        ),
                    ],
                  ),
                ),
              ),

            // C. NAME TAG
            Positioned(
              bottom: widget.isFullScreen ? 50 : 5,
              left: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                constraints: BoxConstraints(
                  maxWidth: widget.isFullScreen ? 300 : 100
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white, 
                          fontSize: 12
                        ),
                      ),
                    ),
                    if (widget.isFullScreen) ...[
                      const SizedBox(width: 4),
                      Icon(
                        participant.isMicrophoneEnabled() 
                            ? Icons.mic 
                            : Icons.mic_off,
                        size: 14,
                        color: participant.isMicrophoneEnabled() 
                            ? Colors.greenAccent 
                            : Colors.redAccent,
                      ),
                    ]
                  ],
                ),
              ),
            ),

            // D. TOUCH HANDLER
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