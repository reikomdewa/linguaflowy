import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    final bool isMe = authState is AuthAuthenticated && authState.user.id == room.hostId;

    final List<RoomMember> allMembers = List<RoomMember>.from(room.members);

    // --------------------------------------------------------
    // DEBUGGING START
    // --------------------------------------------------------
    print("🎨 [RoomCard Build] Room: ${room.title}");
    print("   -> Members List Length: ${allMembers.length}");
    print("   -> Firestore 'memberCount': ${room.memberCount}");
    print("   -> Names: ${allMembers.map((m) => m.displayName).join(', ')}");
    // --------------------------------------------------------

    allMembers.sort((a, b) {
      if (a.uid == room.hostId) return -1;
      if (b.uid == room.hostId) return 1;
      return 0;
    });

    final int realListCount = allMembers.length;
    final int displayCount = math.max(realListCount, room.memberCount);

    final int gridSlots = room.maxMembers > 10 ? 10 : room.maxMembers;
    final bool showOthersBubble = displayCount > 10;

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
                      icon: Icon(Icons.more_vert, color: theme.hintColor, size: 20),
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
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                  return _buildMemberItem(allMembers[index], room.hostId, theme);
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

  // ... [Keep helper widgets like _buildMemberCounter, etc.] ...

  Widget _buildMemberCounter(int current, int max) {
    final displayCurrent = current > max ? max : current;
    final bool isFull = displayCurrent >= max;
    final color = isFull ? Colors.red : Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(Icons.mic, size: 14, color: color),
          const SizedBox(width: 4),
          Text("$displayCurrent/$max", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildMemberItem(RoomMember member, String hostId, ThemeData theme) {
    final bool isHost = member.uid == hostId;
    final String initial = (member.displayName != null && member.displayName!.isNotEmpty)
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
            onBackgroundImageError: imageProvider != null 
                ? (_, __) { print("🖼️ Avatar load failed for ${member.displayName}"); } 
                : null,
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

  Widget _buildJoinButton(BuildContext context, ThemeData theme) {
    return DottedBorder(
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
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text("End Session & Delete Room", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Report submitted")));
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
        content: const Text("Are you sure you want to delete this room? This action is permanent."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
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

  Future<void> _joinRoom(BuildContext context, ChatRoom roomData) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final token = await SpeakService().getLiveKitToken(
        roomData.id,
        FirebaseAuth.instance.currentUser?.displayName ?? "Guest",
      );

      final livekitRoom = Room();
      await livekitRoom.connect('wss://linguaflow-7eemmnrq.livekit.cloud', token);

      if (context.mounted) {
        RoomGlobalManager().joinRoom(livekitRoom, roomData);
        context.read<RoomBloc>().add(JoinRoomEvent(roomData));
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error joining room: $e")));
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              if (passwordController.text.trim() == room.password) {
                Navigator.pop(ctx);
                _joinRoom(context, room);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Incorrect access code."), backgroundColor: Colors.red));
              }
            },
            child: const Text("Join"),
          ),
        ],
      ),
    );
  }
}