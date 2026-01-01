import 'package:flutter/material.dart';
import 'package:linguaflow/screens/speak/active_screen/widgets/participant_tile.dart';
import 'package:livekit_client/livekit_client.dart';

class FullScreenParticipantScreen extends StatelessWidget {
  final Participant participant;

  const FullScreenParticipantScreen({super.key, required this.participant});

  @override
  Widget build(BuildContext context) {
    // Reuse the ParticipantTile logic, but we make it fill the screen
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. The Big Video
          Positioned.fill(
            child: ParticipantTile(
              participant: participant,
              isFullScreen: true, // Tell tile to render differently
            ),
          ),

          // 2. Close Button
          Positioned(
            top: 40,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}