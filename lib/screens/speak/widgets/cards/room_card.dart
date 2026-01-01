import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:linguaflow/screens/speak/active_screen/managers/room_global_manager.dart'; 
import 'package:livekit_client/livekit_client.dart';

// 1. UPDATED BLOC IMPORTS
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/blocs/speak/room/room_bloc.dart';
import 'package:linguaflow/blocs/speak/room/room_event.dart';

// Models & Services
import 'package:linguaflow/models/speak/room_member.dart';
import 'package:linguaflow/models/speak/speak_models.dart'; // Barrel file
import 'package:linguaflow/services/speak/speak_service.dart';
import 'package:linguaflow/utils/language_helper.dart';

class RoomCard extends StatelessWidget {
  final ChatRoom room;

  const RoomCard({super.key, required this.room});

  // --- OPTIONS MENU LOGIC ---
  void _showOptionsMenu(BuildContext context, bool isMe) {
    final theme = Theme.of(context);
    // 2. GET ROOM BLOC
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
            // Drag Handle
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Report submitted")),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text("Share Invite Link"),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  // 3. ACCEPT ROOM BLOC
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Check ownership
    final authState = context.read<AuthBloc>().state;
    final bool isMe =
        authState is AuthAuthenticated && authState.user.id == room.hostId;

    final List<RoomMember> allMembers = List<RoomMember>.from(room.members);
    // Sort host to first position
    allMembers.sort((a, b) {
      if (a.uid == room.hostId) return -1;
      if (b.uid == room.hostId) return 1;
      return 0;
    });

    int displayItemCount;
    bool showOthersBubble = room.memberCount > 10;
    if (showOthersBubble) {
      displayItemCount = 10;
    } else {
      displayItemCount = room.maxMembers > 10 ? 10 : room.maxMembers;
    }

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
            // HEADER ROW
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
                    _buildMemberCounter(room),
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
              itemCount: displayItemCount,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.65,
              ),
              itemBuilder: (context, index) {
                if (showOthersBubble && index == 9) {
                  int remaining = room.memberCount - 9;
                  return _buildOthersIndicator(remaining, theme);
                }
                if (index < allMembers.length) {
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
            _buildJoinButton(context, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCounter(ChatRoom room) {
    final bool isFull = room.memberCount >= room.maxMembers;
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
            "${room.memberCount}/${room.maxMembers}",
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

    return Column(
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
            backgroundImage:
                (member.avatarUrl != null && member.avatarUrl!.isNotEmpty)
                ? NetworkImage(member.avatarUrl!)
                : null,
            child: (member.avatarUrl == null || member.avatarUrl!.isEmpty)
                ? Text((member.displayName ?? "U")[0].toUpperCase())
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isHost ? 'Host' : '${member.xp ?? 0} XP',
              style: TextStyle(
                fontSize: 10,
                color: theme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Column(
      children: [
        // KEEPING YOUR EXACT UI HERE
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

  Widget _buildJoinButton(BuildContext context, ThemeData theme) {
    return DottedBorder(
      // KEEPING YOUR EXACT UI HERE
      options: RoundedRectDottedBorderOptions(
        color: theme.dividerColor,
        strokeWidth: 1.2,
        dashPattern: const [6, 3],
        radius: const Radius.circular(12),
      ),
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: () => room.isPaid
              ? _showPaymentDialog(context)
              : _joinRoom(context, room),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.call_outlined, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                "Join and talk",
                style: TextStyle(
                  color: Colors.blue,
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

 Future<void> _joinRoom(BuildContext context, ChatRoom roomData) async {
    // 1. Show Loading Indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 2. Get Token & Connect to LiveKit
      final token = await SpeakService().getLiveKitToken(
        roomData.id,
        FirebaseAuth.instance.currentUser?.displayName ?? "Guest",
      );

      final livekitRoom = Room();
      
      // Note: Ideally, store this URL in a constant/env file
      await livekitRoom.connect(
        'wss://linguaflow-7eemmnrq.livekit.cloud',
        token,
      );

      if (context.mounted) {
        // --- 3. ACTIVATE THE GLOBAL OVERLAY ---
        // This makes the room appear instantly on top of everything
        RoomGlobalManager().joinRoom(livekitRoom, roomData);

        // --- 4. SYNC WITH FIRESTORE (BLOC) ---
        // This tells the backend "User X has joined Room Y"
        context.read<RoomBloc>().add(JoinRoomEvent(roomData));
        
        // (Optional) If your Bloc needs the LiveKit object for internal logic:
        // context.read<RoomBloc>().add(RoomJoined(livekitRoom));

        // 5. Hide Loading Dialog
        Navigator.pop(context);
        
        // REMOVED: Navigator.push(...) 
        // We no longer navigate to a new screen. The Overlay handles the UI now.
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error joining room: $e")),
        );
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
              obscureText: true, // Hide the numbers like a password
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
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
              final inputCode = passwordController.text.trim();

              // 1. Verify Code
              // We compare the input against the password stored in the room object
              if (inputCode == room.password) {
                Navigator.pop(ctx); // Close dialog
                _joinRoom(context, room); // Proceed to join
              } else {
                // 2. Show Error
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Incorrect access code."),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              "Join",
            ),
          ),
        ],
      ),
    );
  }
}