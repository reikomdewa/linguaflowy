import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:linguaflow/core/env.dart';
import 'package:linguaflow/screens/speak/utils/remote_config_utils.dart';
import 'package:livekit_client/livekit_client.dart';

import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/blocs/speak/room/room_bloc.dart';
import 'package:linguaflow/blocs/speak/room/room_event.dart';
import 'package:linguaflow/models/speak/room_member.dart';
import 'package:linguaflow/models/speak/speak_models.dart';
import 'package:linguaflow/services/speak/speak_service.dart';
import 'package:linguaflow/utils/language_helper.dart';
import 'package:linguaflow/screens/speak/active_screen/managers/room_global_manager.dart';

class RoomCard extends StatelessWidget {
  final ChatRoom room;

  const RoomCard({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = context.read<AuthBloc>().state;

    // Get current User ID safely
    final String currentUserId = (authState is AuthAuthenticated)
        ? authState.user.id
        : '';
    final bool isMe = currentUserId == room.hostId;

    final List<RoomMember> allMembers = List<RoomMember>.from(room.members);

    // Sort members: Host first
    allMembers.sort((a, b) {
      if (a.uid == room.hostId) return -1;
      if (b.uid == room.hostId) return 1;
      return 0;
    });

    final int realListCount = allMembers.length;
    // Ensure display count never drops below reported count (handles lagging lists)
    final int displayCount = math.max(realListCount, room.memberCount);

    final int gridSlots = room.maxMembers > 10 ? 10 : room.maxMembers;
    final bool showOthersBubble = displayCount > 10;

    // --- CHECK IF FULL ---
    final bool isFull = displayCount >= room.maxMembers;
    final bool isAlreadyMember = allMembers.any((m) => m.uid == currentUserId);

    // --- CHECK IF BANNED ---
    // Note: Ensure your ChatRoom model has 'bannedUserIds' list
    final bool isBanned = room.bannedUserIds.contains(currentUserId);

    // You can enter if:
    // 1. The room is NOT full
    // 2. OR You are the Host
    // 3. OR You are already on the list (rejoining)
    // 4. Banned users get a special "Request" flow via the button, so we enable the button for them too
    final bool canEnter = !isFull || isMe || isAlreadyMember;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      LanguageHelper.getFlagEmoji(room.language),
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "${room.language} (${room.level})",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildMemberCounter(displayCount, room.maxMembers),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => _showOptionsMenu(context, isMe),
                      icon: Icon(
                        Icons.more_vert,
                        color: theme.hintColor,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              room.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // MEMBERS GRID
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: gridSlots,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.65,
              ),
              itemBuilder: (context, index) {
                if (showOthersBubble && index == 9) {
                  return _buildOthersIndicator(displayCount - 9, theme);
                }

                if (index < realListCount) {
                  return _buildMemberItem(
                    allMembers[index],
                    room.hostId,
                    theme,
                  );
                }

                return _buildPlaceholder(theme);
              },
            ),
            const SizedBox(height: 20),

            // --- ACTION BUTTON ---
            _buildJoinButton(context, theme, canEnter, isBanned),
          ],
        ),
      ),
    );
  }

  // ========================================================
  // HELPER WIDGETS
  // ========================================================

  Widget _buildMemberCounter(int current, int max) {
    final displayCurrent = current > max ? max : current;
    final bool isFull = displayCurrent >= max;
    final color = isFull ? Colors.red : Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.mic, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            "$displayCurrent/$max",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberItem(RoomMember member, String hostId, ThemeData theme) {
    final bool isHost = member.uid == hostId;
    final String initial =
        (member.displayName != null && member.displayName!.isNotEmpty)
        ? member.displayName![0].toUpperCase()
        : "?";

    ImageProvider? imageProvider;
    if (member.avatarUrl != null && member.avatarUrl!.isNotEmpty) {
      imageProvider = NetworkImage(member.avatarUrl!);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isHost ? theme.primaryColor : Colors.transparent,
              width: 2,
            ),
          ),
          child: CircleAvatar(
            radius: 25,
            backgroundColor: theme.brightness == Brightness.dark
                ? Colors.grey[800]
                : Colors.grey[200],
            backgroundImage: imageProvider,
            onBackgroundImageError: imageProvider != null ? (_, __) {} : null,
            child: imageProvider == null
                ? Text(
                    initial,
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 50,
          child: Text(
            isHost ? 'Host' : '${member.xp ?? 0} XP',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: theme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Column(
      children: [
        DottedBorder(
          options: RoundedRectDottedBorderOptions(
            color: theme.hintColor.withOpacity(0.3),
            strokeWidth: 1,
            dashPattern: const [4, 4],
            radius: const Radius.circular(25),
          ),
          child: const SizedBox(width: 46, height: 46),
        ),
      ],
    );
  }

  Widget _buildOthersIndicator(int count, ThemeData theme) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: theme.primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.primaryColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            "+$count\nothers",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: theme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJoinButton(
    BuildContext context,
    ThemeData theme,
    bool canEnter,
    bool isBanned,
  ) {
    // Determine visuals based on state
    Color color;
    String text;
    IconData icon;

    if (isBanned) {
      color = Colors.red;
      text = "Banned (Request Entry)";
      icon = Icons.block;
    } else if (canEnter) {
      color = Colors.blue;
      text = "Join and talk";
      icon = Icons.call_outlined;
    } else {
      color = Colors.grey;
      text = "Room Full";
      icon = Icons.lock_outline;
    }

    return DottedBorder(
      options: RoundedRectDottedBorderOptions(
        color: (canEnter || isBanned) ? theme.dividerColor : Colors.transparent,
        strokeWidth: 1.2,
        dashPattern: const [6, 3],
        radius: const Radius.circular(12),
      ),
      child: Container(
        decoration: (!canEnter && !isBanned)
            ? BoxDecoration(
                color: theme.disabledColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        width: double.infinity,
        child: TextButton(
          // Logic:
          // If banned -> Handle Request Logic
          // If canEnter -> Join Logic (Payment or Direct)
          // Else -> Show Full Snackbar
          onPressed: (canEnter || isBanned)
              ? () => room.isPaid && !isBanned
                    ? _showPaymentDialog(context)
                    : _joinRoom(context, room)
              : () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "This room has reached its participant limit.",
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========================================================
  // LOGIC & ACTIONS
  // ========================================================

  void _showOptionsMenu(BuildContext context, bool isMe) {
    final theme = Theme.of(context);
    final roomBloc = context.read<RoomBloc>();

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (isMe) ...[
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                ),
                title: const Text(
                  "End Session & Delete Room",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text("This will remove the room for everyone"),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteConfirmation(context, roomBloc);
                },
              ),
              const Divider(),
            ],
            ListTile(
              leading: const Icon(Icons.report_gmailerrorred_rounded),
              title: const Text("Report Room"),
              onTap: () {
                Navigator.pop(ctx);
                // In a real app, you would show the ReportDialog here
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Report submitted")),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, RoomBloc bloc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("End Session?"),
        content: const Text(
          "Are you sure you want to delete this room? This action is permanent.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              bloc.add(DeleteRoomEvent(room.id));
              Navigator.pop(ctx);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // JOIN ROOM LOGIC (Includes Ban/Rejoin Request)
  // -----------------------------------------------------------------------
  Future<void> _joinRoom(BuildContext context, ChatRoom roomData) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // --- 1. BAN CHECK ---
    if (roomData.bannedUserIds.contains(currentUser.uid)) {
      // Check if already requested
      final hasRequested = roomData.joinRequests.any(
        (r) => r['uid'] == currentUser.uid,
      );

      if (hasRequested) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Request pending. Waiting for host approval."),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Show Request Dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("You are banned"),
          content: const Text(
            "You have been removed from this room. Would you like to request to rejoin?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                context.read<RoomBloc>().add(
                  RequestRejoinEvent(
                    roomId: roomData.id,
                    userId: currentUser.uid,
                    displayName: currentUser.displayName ?? "Guest",
                    avatarUrl: currentUser.photoURL,
                  ),
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Rejoin request sent to host.")),
                );
              },
              child: const Text("Request Entry"),
            ),
          ],
        ),
      );
      return; // STOP JOIN PROCESS HERE
    }

    // --- 2. NORMAL JOIN PROCESS ---
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final speakService = SpeakService();
      final roomBloc = context.read<RoomBloc>();

      // A. Get LiveKit Token
      final token = await speakService.getLiveKitToken(
        roomData.id,
        currentUser.displayName ?? "Guest",
      );

      // B. Dispatch Bloc Event (Handles Firestore updates)
      roomBloc.add(JoinRoomEvent(roomData));

      // C. Connect LiveKit
      final livekitRoom = Room();
      // Force refresh config in case URLs changed
      final livekitUrl = await RemoteConfigUtils.getLiveKitUrl(
        forceRefresh: true,
      );

      await livekitRoom.connect(livekitUrl, token);

      if (context.mounted) {
        // D. Activate Global Overlay & Manager
        RoomGlobalManager().joinRoom(livekitRoom, roomData);
        Navigator.pop(context); // Close loading dialog
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog

        final errorStr = e.toString().toLowerCase();

        // --- CHECK FOR LIMIT EXCEEDED ERROR ---
        if (errorStr.contains("limit exceeded") ||
            errorStr.contains("connectexception")) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              icon: const Icon(
                Icons.diamond_outlined,
                size: 48,
                color: Colors.blue,
              ),
              title: const Text("Support Live Chat"),
              content: const Text(
                "Live chat is currently unavailable due to high server maintenance costs.\n\n"
                "Please upgrade to Premium to help support this feature and unlock unlimited access.",
                textAlign: TextAlign.center,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Close"),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.star),
                  label: const Text("Upgrade to Pro"),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber[800], // Gold/Premium color
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);

                    context.push('/premium');
                  },
                ),
              ],
            ),
          );
        } else {
          // --- GENERIC ERROR ---
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Unable to join room. Please try again later."),
              backgroundColor: Colors.red,
            ),
          );
          debugPrint("Error joining room: $e");
        }
      }
    }
  }

  void _showPaymentDialog(BuildContext context) {
    final TextEditingController passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Enter Access Code"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("This room requires a 4-digit code to join."),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: "0000",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              if (passwordController.text.trim() == room.password) {
                Navigator.pop(ctx);
                _joinRoom(context, room);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Incorrect access code."),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text("Join"),
          ),
        ],
      ),
    );
  }
}
