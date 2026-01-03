import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:linguaflow/screens/speak/active_screen/widgets/overlays/participant_tile.dart';

class FullScreenParticipantScreen extends StatelessWidget {
  final Participant participant;

  const FullScreenParticipantScreen({
    super.key,
    required this.participant,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Ensures it covers the grid
      body: Stack(
        children: [
          // The Video Tile
          Positioned.fill(
            child: ParticipantTile(
              participant: participant,
              isFullScreen: true,
              fit: BoxFit.contain, // Contain ensures the whole video is seen
              // We DO NOT pass onTap here, so tapping video doesn't open menu
            ),
          ),
          
          // Optional: Add gradient at bottom for better text visibility
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 100,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}