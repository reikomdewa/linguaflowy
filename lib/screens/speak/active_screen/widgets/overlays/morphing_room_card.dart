import 'package:flutter/material.dart';
import 'package:linguaflow/screens/speak/active_screen/managers/room_global_manager.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:linguaflow/screens/speak/active_screen/widgets/participant_tile.dart';
import 'room_controls.dart'; // Import controls

class MorphingRoomCard extends StatelessWidget {
  final RoomGlobalManager manager;
  final List<Participant> participants;
  final int unreadCount;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenMenu;
  final VoidCallback onClosePress;
  final Function(Participant) onParticipantTap;

  const MorphingRoomCard({
    super.key,
    required this.manager,
    required this.participants,
    required this.unreadCount,
    required this.onOpenChat,
    required this.onOpenMenu,
    required this.onClosePress,
    required this.onParticipantTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double width = manager.isExpanded ? size.width : 120;
    final double height = manager.isExpanded ? size.height : 160;
    final double bottomMargin = manager.isExpanded ? 0 : 160;
    final double rightMargin = manager.isExpanded ? 0 : 16;
    final double radius = manager.isExpanded ? 0 : 16;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: width,
      height: height,
      margin: EdgeInsets.only(bottom: bottomMargin, right: rightMargin),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          if (!manager.isExpanded)
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Material(
          color: Colors.transparent,
          child: manager.isExpanded
              ? _buildExpandedView(context)
              : _buildMiniView(context),
        ),
      ),
    );
  }

  Widget _buildMiniView(BuildContext context) {
    final localP = manager.livekitRoom?.localParticipant;
    final isMicOn = localP?.isMicrophoneEnabled() ?? false;
    final isCamOn = localP?.isCameraEnabled() ?? false;

    return GestureDetector(
      onTap: manager.expand,
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < 0) manager.expand();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (participants.isNotEmpty)
            Opacity(opacity: 0.6, child: ParticipantTile(participant: participants.first, fit: BoxFit.cover))
          else
            Container(color: Colors.grey[900]),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    const Text("LIVE", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  MiniIconButton(icon: isMicOn ? Icons.mic : Icons.mic_off, color: isMicOn ? Colors.white : Colors.red, onTap: manager.toggleMic),
                  MiniIconButton(icon: isCamOn ? Icons.videocam : Icons.videocam_off, color: isCamOn ? Colors.white : Colors.grey, onTap: manager.toggleCamera),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
          Positioned(top: 4, right: 4, child: Icon(Icons.open_in_full_rounded, color: Colors.white.withOpacity(0.7), size: 16)),
        ],
      ),
    );
  }

  Widget _buildExpandedView(BuildContext context) {
    final localP = manager.livekitRoom?.localParticipant;
    final isMicOn = localP?.isMicrophoneEnabled() ?? false;
    final isCamOn = localP?.isCameraEnabled() ?? false;

    return SafeArea(
      child: Column(
        children: [
          // TOP BAR
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundImage: manager.roomData?.hostAvatarUrl != null ? NetworkImage(manager.roomData!.hostAvatarUrl!) : null,
                        child: manager.roomData?.hostAvatarUrl == null ? const Icon(Icons.person, size: 16) : null,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(manager.roomData?.title ?? "Live Room", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          Text("${participants.length} in live", style: const TextStyle(color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                        child: const Text("LIVE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 30), onPressed: manager.collapse),
                IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: onClosePress),
              ],
            ),
          ),
          
          // GRID
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.8,
                ),
                itemCount: participants.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => onParticipantTap(participants[index]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(color: Colors.grey[900], border: Border.all(color: Colors.white10, width: 1)),
                        child: ParticipantTile(participant: participants[index]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // BOTTOM BAR
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onOpenChat,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(22)),
                      child: Row(
                        children: [
                          Text("Say something...", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)),
                          const Spacer(),
                          if (unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                              child: Text("$unreadCount", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GlassButton(icon: isMicOn ? Icons.mic : Icons.mic_off, isRed: !isMicOn, onTap: manager.toggleMic),
                const SizedBox(width: 8),
                GlassButton(icon: isCamOn ? Icons.videocam : Icons.videocam_off, onTap: manager.toggleCamera),
                const SizedBox(width: 8),
                GlassButton(icon: Icons.more_horiz, onTap: onOpenMenu),
              ],
            ),
          ),
        ],
      ),
    );
  }
}