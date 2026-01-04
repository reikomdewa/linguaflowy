import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:linguaflow/blocs/speak/room/room_bloc.dart';
import 'package:linguaflow/blocs/speak/room/room_event.dart';
import 'package:linguaflow/screens/speak/active_screen/managers/room_global_manager.dart';
import 'package:share_plus/share_plus.dart';

class RoomMenuSheet extends StatelessWidget {
  final RoomGlobalManager manager;
  final bool isHost;
  final VoidCallback onClose;

  // Callbacks for Parent (LiveRoomOverlay)
  final VoidCallback onOpenRequests;
  final VoidCallback onOpenYouTube;
  final Function(bool isBanning) onOpenUserManagement;
  final VoidCallback onOpenEdit;
  final VoidCallback onOpenReport;

  const RoomMenuSheet({
    super.key,
    required this.manager,
    required this.isHost,
    required this.onClose,
    required this.onOpenRequests,
    required this.onOpenYouTube,
    required this.onOpenUserManagement,
    required this.onOpenEdit,
    required this.onOpenReport,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final double screenWidth = MediaQuery.of(context).size.width;

    // --- 1. DETERMINE PLATFORM/SIZE ---
    // If width > 600, we treat it as desktop/tablet for layout purposes
    final bool isDesktop = screenWidth > 600;

    // Your original Mobile calculation
    final double mobileItemWidth = (screenWidth - 32) / 4.5;

    final bool isFeatureGloballyActive =
        manager.activeFeature != RoomActiveFeature.none;
    final bool isLocalTiles = manager.isLocalTileView;

    // --- REQUESTS LOGIC ---
    final List<dynamic> youtubeRequests =
        manager.roomData?.youtubeRequests ?? [];

    Map<String, dynamic> myRequest = {};
    if (currentUserId != null && youtubeRequests.isNotEmpty) {
      for (var req in youtubeRequests) {
        if (req is Map && req['userId'] == currentUserId) {
          myRequest = Map<String, dynamic>.from(req);
          break;
        }
      }
    }

    final bool hasYouTubeRequested = myRequest.isNotEmpty;
    final bool hasBoardRequested =
        manager.roomData?.boardRequests?.contains(currentUserId) ?? false;
    final bool hasPendingRequests =
        (manager.roomData?.boardRequests?.isNotEmpty ?? false) ||
        (youtubeRequests.isNotEmpty) ||
        (manager.roomData?.joinRequests.isNotEmpty ?? false);

    // --- PAUSE STATE ---
    final bool isRoomPaused = manager.roomData?.isPrivate ?? false;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Material(
          color: const Color(0xFF1E1E1E),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          elevation: 10,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // DRAG HANDLE
                GestureDetector(
                  onTap: onClose,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[700],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                const Text(
                  "Settings",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ===========================
                      // 1. MEDIA SECTION
                      // ===========================
                      _buildSectionHeader("Media"),
                      _buildAdaptiveLayout(
                        isDesktop: isDesktop,
                        mobileItemWidth: mobileItemWidth,
                        items: [
                          // FLIP CAMERA
                          _OptionItem(
                            icon: Icons.flip_camera_ios_outlined,
                            label: "Flip",
                            onTap: manager.switchCamera,
                          ),

                          // SHARE SCREEN
                          _OptionItem(
                            icon: Icons.screen_share_outlined,
                            label: "Share Screen",
                            onTap: () {
                              manager.toggleScreenShare();
                              onClose();
                            },
                          ),

                          // TOGGLE TILES / BOARD
                          if (isFeatureGloballyActive)
                            _OptionItem(
                              icon: isLocalTiles
                                  ? Icons.featured_video_outlined
                                  : Icons.grid_view_rounded,
                              label: isLocalTiles ? "Board" : "Tiles",
                              color: Colors.greenAccent,
                              onTap: () {
                                manager.toggleLocalTileView();
                                onClose();
                              },
                            ),

                          // --- HOST: MY BOARD ---
                          if (isHost)
                            _OptionItem(
                              icon: Icons.edit_note_rounded,
                              label: "My Board",
                              onTap: () {
                                if (manager.roomData != null &&
                                    currentUserId != null) {
                                  context.read<RoomBloc>().add(
                                    GrantBoardAccessEvent(
                                      roomId: manager.roomData!.id,
                                      targetUserId: currentUserId,
                                    ),
                                  );
                                }
                                onClose();
                              },
                            ),

                          // --- HOST: VIEW REQUESTS ---
                          if (isHost && hasPendingRequests)
                            _OptionItem(
                              icon: Icons.assignment_ind,
                              label: "Requests",
                              color: Colors.amber,
                              onTap: () {
                                onClose();
                                onOpenRequests();
                              },
                            ),

                          // --- GUEST: SHARE BOARD REQUEST ---
                          if (!isHost)
                            _OptionItem(
                              icon: hasBoardRequested
                                  ? Icons.hourglass_top
                                  : Icons.edit_note_rounded,
                              label: hasBoardRequested
                                  ? "Waiting..."
                                  : "Share Board",
                              color: hasBoardRequested
                                  ? Colors.amber
                                  : Colors.white,
                              onTap: () {
                                if (currentUserId == null) return;
                                if (hasBoardRequested) {
                                  context.read<RoomBloc>().add(
                                    CancelBoardRequestEvent(
                                      roomId: manager.roomData!.id,
                                      userId: currentUserId,
                                    ),
                                  );
                                } else {
                                  context.read<RoomBloc>().add(
                                    RequestBoardAccessEvent(
                                      roomId: manager.roomData!.id,
                                      userId: currentUserId,
                                    ),
                                  );
                                }
                                onClose();
                              },
                            ),

                          // --- YOUTUBE ---
                          _OptionItem(
                            icon: isHost
                                ? Icons.ondemand_video_rounded
                                : (hasYouTubeRequested
                                      ? Icons.hourglass_top
                                      : Icons.ondemand_video_rounded),
                            label: isHost
                                ? "YouTube"
                                : (hasYouTubeRequested
                                      ? "Waiting..."
                                      : "Req Video"),
                            color: hasYouTubeRequested
                                ? Colors.amber
                                : Colors.white,
                            onTap: () {
                              onClose();
                              if (isHost) {
                                onOpenYouTube();
                              } else {
                                if (currentUserId == null) return;
                                if (hasYouTubeRequested) {
                                  context.read<RoomBloc>().add(
                                    CancelYouTubeRequestEvent(
                                      roomId: manager.roomData!.id,
                                      requestMap: myRequest,
                                    ),
                                  );
                                } else {
                                  onOpenYouTube();
                                }
                              }
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      // ===========================
                      // 2. HOST TOOLS SECTION
                      // ===========================
                      if (isHost) ...[
                        _buildSectionHeader("Host Tools"),
                        _buildAdaptiveLayout(
                          isDesktop: isDesktop,
                          mobileItemWidth: mobileItemWidth,
                          items: [
                            // EDIT
                            _OptionItem(
                              icon: Icons.edit,
                              label: "Edit",
                              onTap: () {
                                onClose();
                                onOpenEdit();
                              },
                            ),

                            // PAUSE
                            _OptionItem(
                              icon: isRoomPaused
                                  ? Icons.play_circle_outline
                                  : Icons.pause_circle_outline,
                              label: isRoomPaused ? "Resume" : "Pause",
                              color: isRoomPaused ? Colors.amber : Colors.white,
                              onTap: () {
                                context.read<RoomBloc>().add(
                                  ToggleRoomLockEvent(
                                    roomId: manager.roomData!.id,
                                    isLocked: !isRoomPaused,
                                  ),
                                );
                              },
                            ),

                            // MUTES
                            _OptionItem(
                              icon: Icons.mic_off_outlined,
                              label: "Mutes",
                              onTap: () {
                                onClose();
                                onOpenUserManagement(false);
                              },
                            ),

                            // BANS
                            _OptionItem(
                              icon: Icons.block,
                              label: "Bans",
                              color: Colors.redAccent,
                              onTap: () {
                                onClose();
                                onOpenUserManagement(true);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                      ],

                      // ===========================
                      // 3. GENERAL SECTION
                      // ===========================
                      _buildSectionHeader("General"),
                      _buildAdaptiveLayout(
                        isDesktop: isDesktop,
                        mobileItemWidth: mobileItemWidth,
                        items: [
                          // INVITE
                          _OptionItem(
                            icon: Icons.share,
                            label: "Invite",
                            onTap: () {
                              if (manager.roomData != null)
                                Share.share(
                                  "Join room: ${manager.roomData!.id}",
                                );
                            },
                          ),

                          // REPORT
                          _OptionItem(
                            icon: Icons.report_problem_outlined,
                            label: "Report",
                            color: Colors.orangeAccent,
                            onTap: () {
                              onClose();
                              onOpenReport();
                            },
                          ),

                          // LEAVE
                          _OptionItem(
                            icon: Icons.logout,
                            label: "Leave",
                            color: Colors.redAccent,
                            onTap: () {
                              onClose();
                              manager.leaveRoom();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// -----------------------------------------------------------
  /// HYBRID LAYOUT BUILDER
  /// Uses GridView on Desktop, Wrap on Mobile
  /// -----------------------------------------------------------
  Widget _buildAdaptiveLayout({
    required bool isDesktop,
    required double mobileItemWidth,
    required List<_OptionItem> items,
  }) {
    if (isDesktop) {
      // DESKTOP: Use Grid to force alignment
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, // Force 4 items per row
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.1,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return _buildSingleItem(items[index]);
        },
      );
    } else {
      // MOBILE: Use your original Wrap logic
      return Wrap(
        spacing: 12,
        runSpacing: 16,
        children: items.map((item) {
          return SizedBox(
            width: mobileItemWidth, // Keeps your original mobile sizing
            child: _buildSingleItem(item),
          );
        }).toList(),
      );
    }
  }

  // Helper to build the actual icon+text (Shared by both Desktop and Mobile)
  Widget _buildSingleItem(_OptionItem item) {
    return GestureDetector(
      onTap: item.onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment:
            MainAxisAlignment.center, // Added center for grid alignment
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            item.label,
            style: TextStyle(color: item.color, fontSize: 10),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _OptionItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  _OptionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });
}
