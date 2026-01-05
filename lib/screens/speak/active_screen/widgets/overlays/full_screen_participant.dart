import 'package:flutter/material.dart';
import 'package:linguaflow/screens/speak/active_screen/widgets/overlays/participant_tile.dart';
import 'package:livekit_client/livekit_client.dart';

class FullScreenParticipantScreen extends StatefulWidget {
  final Participant participant;

  const FullScreenParticipantScreen({
    super.key,
    required this.participant,
  });

  @override
  State<FullScreenParticipantScreen> createState() =>
      _FullScreenParticipantScreenState();
}

class _FullScreenParticipantScreenState
    extends State<FullScreenParticipantScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. The Big Video
          Positioned.fill(
            child: ParticipantTile(
              participant: widget.participant,
              isFullScreen: true,
              fit: BoxFit.contain, // Screen share needs 'contain' to be readable
            ),
          ),

        ],
      ),
    );
  }
}


