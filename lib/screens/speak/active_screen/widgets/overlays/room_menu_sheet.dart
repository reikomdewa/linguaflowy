import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:linguaflow/blocs/speak/room/room_bloc.dart';
import 'package:linguaflow/blocs/speak/room/room_event.dart';
import 'package:linguaflow/screens/speak/active_screen/managers/room_global_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:linguaflow/core/globals.dart';

class RoomMenuSheet extends StatelessWidget {
  final RoomGlobalManager manager;
  final bool isHost;
  final VoidCallback onClose;
  final VoidCallback onOpenRequests; // <--- NEW CALLBACK

  const RoomMenuSheet({
    super.key,
    required this.manager,
    required this.isHost,
    required this.onClose,
    required this.onOpenRequests, // Require it
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double itemWidth = (screenWidth - 32) / 4.5;

    final bool isFeatureGloballyActive =
        manager.activeFeature != RoomActiveFeature.none;
    final bool isLocalTiles = manager.isLocalTileView;
    final bool hasRequested =
        manager.roomData?.boardRequests?.contains(currentUserId) ?? false;
    final bool hasPendingRequests =
        (manager.roomData?.boardRequests?.isNotEmpty ?? false);

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
                GestureDetector(
                  onTap: onClose,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 15, bottom: 15),
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
                      _buildSectionHeader("Media"),
                      _buildWrapOptions([
                        _OptionItem(
                          icon: Icons.flip_camera_ios_outlined,
                          label: "Flip",
                          onTap: manager.switchCamera,
                        ),
                        _OptionItem(
                          icon: Icons.screen_share_outlined,
                          label: "Share Screen",
                          onTap: () {
                            manager.toggleScreenShare();
                            onClose();
                          },
                        ),

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

                        // --- 3. HOST: REQUESTS (Stack Logic) ---
                        if (isHost && hasPendingRequests)
                          _OptionItem(
                            icon: Icons.assignment_ind,
                            label: "Requests",
                            color: Colors.amber,
                            onTap: () {
                              onClose(); // Close settings
                              onOpenRequests(); // Tell parent to open requests
                            },
                          ),

                        if (!isHost)
                          _OptionItem(
                            icon: hasRequested
                                ? Icons.hourglass_top
                                : Icons.edit_note_rounded,
                            label: hasRequested ? "Waiting..." : "Share Board",
                            color: hasRequested ? Colors.amber : Colors.white,
                            onTap: () {
                              if (currentUserId == null) return;
                              if (hasRequested) {
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

                        _OptionItem(
                          icon: Icons.ondemand_video_rounded,
                          label: "YouTube",
                          onTap: () => _showYouTubeInput(context),
                        ),
                      ], itemWidth),

                      const SizedBox(height: 15),
                      if (isHost) ...[
                        _buildSectionHeader("Host Tools"),
                        _buildWrapOptions([
                          _OptionItem(
                            icon: Icons.edit,
                            label: "Edit",
                            onTap: () {},
                          ),
                          _OptionItem(
                            icon: Icons.pause_circle_outline,
                            label: "Pause",
                            onTap: () {},
                          ),
                          _OptionItem(
                            icon: Icons.mic_off_outlined,
                            label: "Mutes",
                            onTap: () {},
                          ),
                          _OptionItem(
                            icon: Icons.block,
                            label: "Bans",
                            onTap: () {},
                          ),
                        ], itemWidth),
                        const SizedBox(height: 15),
                      ],
                      _buildSectionHeader("General"),
                      _buildWrapOptions([
                        _OptionItem(
                          icon: Icons.share,
                          label: "Invite",
                          onTap: () {
                            if (manager.roomData != null)
                              Share.share("Join room: ${manager.roomData!.id}");
                          },
                        ),
                        _OptionItem(
                          icon: Icons.report_problem_outlined,
                          label: "Report",
                          color: Colors.redAccent,
                          onTap: () {},
                        ),
                        _OptionItem(
                          icon: Icons.logout,
                          label: "Leave",
                          color: Colors.redAccent,
                          onTap: () {
                            onClose();
                            manager.leaveRoom();
                          },
                        ),
                      ], itemWidth),
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

  void _showYouTubeInput(BuildContext context) {
    // Keep YouTube logic as is, or use same pattern if it fails
    final globalContext = navigatorKey.currentContext ?? context;
    final controller = TextEditingController();
    showDialog(
      context: globalContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text(
          "Watch YouTube",
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Paste Link...",
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              if (isHost && manager.roomData != null) {
                context.read<RoomBloc>().add(
                  UpdateActiveFeatureEvent(
                    roomId: manager.roomData!.id,
                    feature: 'youtube',
                    data: controller.text,
                  ),
                );
              }
              Navigator.of(ctx).pop();
              onClose();
            },
            child: const Text("Play"),
          ),
        ],
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

  Widget _buildWrapOptions(List<_OptionItem> items, double itemWidth) {
    return Wrap(
      spacing: 12,
      runSpacing: 16,
      alignment: WrapAlignment.start,
      children: items.map((item) {
        return SizedBox(
          width: itemWidth,
          child: GestureDetector(
            onTap: item.onTap,
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
          ),
        );
      }).toList(),
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
