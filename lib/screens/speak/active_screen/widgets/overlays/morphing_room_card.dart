import 'package:flutter/material.dart';
import 'package:linguaflow/screens/speak/active_screen/managers/room_global_manager.dart';
import 'package:linguaflow/screens/speak/active_screen/widgets/overlays/live_stats_view.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:linguaflow/screens/speak/active_screen/widgets/overlays/participant_tile.dart';
import 'package:linguaflow/screens/speak/widgets/sheets/room_chat_sheet.dart';
import 'package:linguaflow/screens/speak/active_screen/widgets/features/whiteboard_feature.dart';
import 'package:share_plus/share_plus.dart';
import 'room_controls.dart'; 

// BLOC IMPORTS
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/speak/room/room_bloc.dart';
import 'package:linguaflow/blocs/speak/room/room_event.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MorphingRoomCard extends StatefulWidget {
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
  State<MorphingRoomCard> createState() => _MorphingRoomCardState();
}

class _MorphingRoomCardState extends State<MorphingRoomCard> {
  final PageController _pageController = PageController();
  ScrollPhysics _pagePhysics = const NeverScrollableScrollPhysics();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double width = widget.manager.isExpanded ? size.width : 120;
    final double height = widget.manager.isExpanded ? size.height : 160;
    final double bottomMargin = widget.manager.isExpanded ? 0 : 160;
    final double rightMargin = widget.manager.isExpanded ? 0 : 16;
    final double radius = widget.manager.isExpanded ? 0 : 16;

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
          if (!widget.manager.isExpanded)
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Material(
          color: Colors.transparent,
          child: widget.manager.isExpanded
              ? _buildExpandedView(context)
              : _buildMiniView(context),
        ),
      ),
    );
  }

  Widget _buildMiniView(BuildContext context) {
    final localP = widget.manager.livekitRoom?.localParticipant;
    final isMicOn = localP?.isMicrophoneEnabled() ?? false;
    final isCamOn = localP?.isCameraEnabled() ?? false;

    return GestureDetector(
      onTap: widget.manager.expand,
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < 0) widget.manager.expand();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.participants.isNotEmpty)
            Opacity(
              opacity: 0.6,
              child: ParticipantTile(
                participant: widget.participants.first,
                fit: BoxFit.cover,
              ),
            )
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
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      "LIVE",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  MiniIconButton(
                    icon: isMicOn ? Icons.mic : Icons.mic_off,
                    color: isMicOn ? Colors.white : Colors.red,
                    onTap: widget.manager.toggleMic,
                  ),
                  MiniIconButton(
                    icon: isCamOn ? Icons.videocam : Icons.videocam_off,
                    color: isCamOn ? Colors.white : Colors.grey,
                    onTap: widget.manager.toggleCamera,
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Icon(
              Icons.open_in_full_rounded,
              color: Colors.white.withOpacity(0.7),
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedView(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isDesktop = constraints.maxWidth > 900;
          if (isDesktop) {
            return Row(
              children: [
                Expanded(
                  child: _buildVideoContent(context, showChatButton: false),
                ),
                Container(width: 1, color: Colors.white10),
                SizedBox(
                  width: 400,
                  child: widget.manager.roomData != null
                      ? RoomChatSheet(room: widget.manager.livekitRoom!)
                      : const Center(child: CircularProgressIndicator()),
                ),
              ],
            );
          } else {
            return Listener(
              onPointerDown: (event) {
                final double screenWidth = MediaQuery.of(context).size.width;
                final double touchX = event.position.dx;
                const double edgeWidth = 35.0; 
                final bool isEdgeSwipe = touchX > (screenWidth - edgeWidth) || touchX < edgeWidth;

                if (isEdgeSwipe) {
                  if (_pagePhysics is! BouncingScrollPhysics) {
                    setState(() => _pagePhysics = const BouncingScrollPhysics());
                  }
                } else {
                  if (_pagePhysics is! NeverScrollableScrollPhysics) {
                    setState(() => _pagePhysics = const NeverScrollableScrollPhysics());
                  }
                }
              },
              child: PageView(
                controller: _pageController,
                physics: _pagePhysics,
                scrollDirection: Axis.horizontal,
                children: [
                  _buildVideoContent(context, showChatButton: true),
                  LiveStatsView(manager: widget.manager),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildVideoContent(
    BuildContext context, {
    required bool showChatButton,
  }) {
    // Check Local Tile View
    final isFeatureActive =
        widget.manager.activeFeature != RoomActiveFeature.none &&
        !widget.manager.isLocalTileView; 

    final localP = widget.manager.livekitRoom?.localParticipant;
    final isMicOn = localP?.isMicrophoneEnabled() ?? false;
    final isCamOn = localP?.isCameraEnabled() ?? false;

    // --- LOGIC FOR YELLOW DOT ---
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isHost = widget.manager.roomData?.hostId == currentUserId;
    final hasPendingRequests = (widget.manager.roomData?.boardRequests?.isNotEmpty ?? false);
    // Show dot if I am host AND there are requests
    final showMenuDot = isHost && hasPendingRequests;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              _buildHostInfoPill(),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.ios_share,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () {
                  if (widget.manager.roomData != null) {
                    Share.share(
                      "Join my live room! ID: ${widget.manager.roomData!.id}",
                    );
                  }
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: widget.manager.collapse,
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: widget.onClosePress,
              ),
            ],
          ),
        ),
        Expanded(
          child: isFeatureActive
              ? _buildActiveFeatureView()
              : _buildParticipantGrid(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showChatButton) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: widget.onOpenChat,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          Text(
                            "Say something...",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          if (widget.unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "${widget.unreadCount}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              GlassButton(
                icon: isMicOn ? Icons.mic : Icons.mic_off,
                isRed: !isMicOn,
                onTap: widget.manager.toggleMic,
              ),
              const SizedBox(width: 8),
              GlassButton(
                icon: isCamOn ? Icons.videocam : Icons.videocam_off,
                onTap: widget.manager.toggleCamera,
              ),
              const SizedBox(width: 8),
              
              // --- MODIFIED MENU BUTTON WITH DOT ---
              Stack(
                alignment: Alignment.topRight,
                clipBehavior: Clip.none,
                children: [
                  GlassButton(icon: Icons.more_horiz, onTap: widget.onOpenMenu),
                  if (showMenuDot)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 2), // Tiny border for contrast
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHostInfoPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundImage: widget.manager.roomData?.hostAvatarUrl != null
                ? NetworkImage(widget.manager.roomData!.hostAvatarUrl!)
                : null,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.manager.roomData?.title ?? "Live Room",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${widget.participants.length} in live",
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              "LIVE",
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFeatureView() {
    if (widget.manager.activeFeature == RoomActiveFeature.whiteboard) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CollaborativeWhiteboard(
            manager: widget.manager,
          ), 
        ),
      );
    } else if (widget.manager.activeFeature == RoomActiveFeature.youtube) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Text(
            "Playing YouTube: ${widget.manager.activeFeatureData ?? ''}",
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildParticipantGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount = width > 800 ? 5 : (width > 600 ? 4 : 3);
        double childAspectRatio = width > 800 ? 1.0 : 0.8;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            padding: EdgeInsets.zero,
            physics: const BouncingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: childAspectRatio,
            ),
            itemCount: widget.participants.length,
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    border: Border.all(color: Colors.white10, width: 1),
                  ),
                  child: ParticipantTile(
                    participant: widget.participants[index],
                    onTap: () =>
                        widget.onParticipantTap(widget.participants[index]),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}