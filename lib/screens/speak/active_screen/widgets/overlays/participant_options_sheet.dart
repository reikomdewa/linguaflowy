import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:linguaflow/models/speak/speak_models.dart';
import 'package:linguaflow/models/speak/room_member.dart';
import 'package:linguaflow/core/globals.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/services/speak/private_chat_service.dart';
import 'package:linguaflow/screens/inbox/private_chat_screen.dart';
import 'package:linguaflow/screens/speak/active_screen/managers/room_global_manager.dart';

class ParticipantOptionsSheet extends StatelessWidget {
  final Participant targetParticipant;
  final bool amIHost;
  final String? currentSpotlightId;
  final ChatRoom roomData;
  final VoidCallback onClose;
  
  // CALLBACKS (Fixes Context/Bloc Issues)
  final Function(Participant) onSetFullScreen;
  final Function(String?) onToggleSpotlight; // Passes User ID or Null
  final Function(String) onKickUser;         // Passes User ID

  const ParticipantOptionsSheet({
    super.key,
    required this.targetParticipant,
    required this.amIHost,
    required this.currentSpotlightId,
    required this.roomData,
    required this.onClose,
    required this.onSetFullScreen,
    required this.onToggleSpotlight,
    required this.onKickUser,
  });

  // --- ACTIONS ---

  void _handleFullScreen() {
    onClose();
    Future.delayed(const Duration(milliseconds: 100), () {
      onSetFullScreen(targetParticipant);
    });
  }

  Future<void> _toggleMyMic() async {
    final manager = RoomGlobalManager();
    await manager.toggleMic();
    onClose();
  }

  Future<void> _toggleMyCam() async {
    final manager = RoomGlobalManager();
    await manager.toggleCamera();
    onClose();
  }

  Future<void> _flipMyCamera() async {
    final manager = RoomGlobalManager();
    await manager.switchCamera();
    onClose();
  }

  void _handleSpotlight() {
    // Logic: If currently spotlighted, send null (remove). Else send ID (add).
    final isCurrentlySpotlighted = currentSpotlightId == targetParticipant.identity;
    final userIdToSet = isCurrentlySpotlighted ? null : targetParticipant.identity;
    
    // Execute Callback using Parent's Context
    onToggleSpotlight(userIdToSet);
    onClose();
  }

  void _confirmKick(BuildContext context) {
    // Use global context for Dialog to ensure it overlays correctly
    final dialogContext = navigatorKey.currentContext ?? context;

    showDialog(
      context: dialogContext,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text("Kick User?", style: TextStyle(color: Colors.white)),
        content: const Text("This will remove them from the room.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              // Execute Callback
              onKickUser(targetParticipant.identity!);
              onClose(); 
            },
            child: const Text("Kick", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _initiatePrivateChat() async {
    // Private chat navigation still needs global context as it pushes a new screen
    final navContext = navigatorKey.currentContext;
    if (navContext == null) return;

    final authState = navContext.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      final myUser = authState.user;
      final targetId = targetParticipant.identity;
      
      RoomMember? targetMember;
      try {
        targetMember = roomData.members.firstWhere((m) => m.uid == targetId);
      } catch (_) {}

      onClose();
      RoomGlobalManager().collapse();

      try {
        final chatId = await PrivateChatService().startChat(
          currentUserId: myUser.id,
          otherUserId: targetId!,
          currentUserName: myUser.displayName,
          otherUserName: targetMember?.displayName ?? targetParticipant.name,
          currentUserPhoto: myUser.photoUrl,
          otherUserPhoto: targetMember?.avatarUrl,
        );
        Navigator.of(navContext).push(
          MaterialPageRoute(
            builder: (_) => PrivateChatScreen(
              chatId: chatId,
              otherUserName: targetMember?.displayName ?? targetParticipant.name,
              otherUserPhoto: targetMember?.avatarUrl,
            ),
          ),
        );
      } catch (e) {
        debugPrint("Error starting chat: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    // Strict "Is Me" Logic
    bool isMe = targetParticipant is LocalParticipant;
    if (!isMe && currentUserId != null) {
      isMe = targetParticipant.identity == currentUserId;
    }
    
    final isMicOn = targetParticipant.isMicrophoneEnabled();
    final isCamOn = targetParticipant.isCameraEnabled();
    final isSpotlighted = currentSpotlightId == targetParticipant.identity;

    final double screenWidth = MediaQuery.of(context).size.width;
    final double itemWidth = (screenWidth - 32) / 4.5; 

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Material(
          color: const Color(0xFF1E1E1E),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: onClose,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 15, bottom: 10),
                      child: Center(
                        child: Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isMe) const Text("(You) ", style: TextStyle(color: Colors.grey, fontSize: 14)),
                        Flexible(
                          child: Text(
                            targetParticipant.name.isNotEmpty ? targetParticipant.name : "User",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 20,
                      alignment: WrapAlignment.center,
                      children: [
                        
                        _buildOption(icon: Icons.fullscreen, label: "Full Screen", onTap: _handleFullScreen, width: itemWidth),

                        if (isMe) ...[
                          _buildOption(icon: isMicOn ? Icons.mic : Icons.mic_off, label: isMicOn ? "Mute" : "Unmute", color: isMicOn ? Colors.white : Colors.redAccent, onTap: _toggleMyMic, width: itemWidth),
                          _buildOption(icon: isCamOn ? Icons.videocam : Icons.videocam_off, label: isCamOn ? "Stop Cam" : "Start Cam", onTap: _toggleMyCam, width: itemWidth),
                          _buildOption(icon: Icons.flip_camera_ios, label: "Flip", onTap: _flipMyCamera, width: itemWidth),
                        ],

                        if (!isMe) ...[
                          _buildOption(icon: Icons.chat_bubble_outline_rounded, label: "Message", color: Colors.blueAccent, onTap: _initiatePrivateChat, width: itemWidth),
                        ],

                        if (amIHost) ...[
                          _buildOption(
                            icon: isSpotlighted ? Icons.star : Icons.star_border,
                            label: isSpotlighted ? "Un-Spot" : "Spotlight",
                            color: Colors.amber,
                            onTap: _handleSpotlight,
                            width: itemWidth,
                          ),
                          if (!isMe)
                            _buildOption(icon: Icons.remove_circle_outline, label: "Kick", color: Colors.redAccent, onTap: () => _confirmKick(context), width: itemWidth),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOption({required IconData icon, required String label, required VoidCallback onTap, required double width, Color color = Colors.white}) {
    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontSize: 11), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}