import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:linguaflow/core/globals.dart';
import 'package:linguaflow/screens/speak/active_screen/managers/room_global_manager.dart';
import 'package:livekit_client/livekit_client.dart';

// INTERNAL IMPORTS
import 'package:linguaflow/screens/inbox/private_chat_screen.dart';
import 'package:linguaflow/services/speak/private_chat_service.dart';
import 'package:linguaflow/models/speak/speak_models.dart';
import 'package:linguaflow/models/speak/room_member.dart';

// BLOC
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/blocs/speak/room/room_bloc.dart';
import 'package:linguaflow/blocs/speak/room/room_event.dart' hide RoomEvent;

// GLOBAL

// --- MENU SHEET ---
class RoomMenuSheet extends StatelessWidget {
  final RoomGlobalManager manager;
  final VoidCallback onClose;

  const RoomMenuSheet({
    super.key,
    required this.manager,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2C2C2C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Settings",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(
                Icons.close_fullscreen,
                color: Colors.blueAccent,
              ),
              title: const Text(
                "Minimize Room",
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                manager.collapse();
                onClose();
              },
            ),
            const SizedBox(height: 10),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.close, color: Colors.white),
              title: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white),
              ),
              onTap: onClose,
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

// --- LEAVE CONFIRMATION DIALOG ---
class LeaveConfirmDialog extends StatelessWidget {
  final ChatRoom? roomData;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const LeaveConfirmDialog({
    super.key,
    required this.roomData,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isHost = roomData?.hostId == currentUid;
    final title = isHost ? "End Session?" : "Leave Room?";
    final subtitle = isHost
        ? "This will disconnect everyone."
        : "Stop watching?";
    final buttonText = isHost ? "End Session" : "Leave";

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onCancel,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Colors.white24),
                      ),
                    ),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      buttonText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- PARTICIPANT OPTIONS SHEET ---
class ParticipantOptionsSheet extends StatelessWidget {
  final Participant targetParticipant;
  final bool amIHost;
  final String? currentSpotlightId;
  final ChatRoom roomData;
  final VoidCallback onClose;
  final VoidCallback onSetFullScreen;

  const ParticipantOptionsSheet({
    super.key,
    required this.targetParticipant,
    required this.amIHost,
    required this.currentSpotlightId,
    required this.roomData,
    required this.onClose,
    required this.onSetFullScreen,
  });

  Future<void> _initiatePrivateChat(BuildContext context) async {
    final navContext = navigatorKey.currentContext!;
    final authState = navContext.read<AuthBloc>().state;

    if (authState is AuthAuthenticated) {
      final myUser = authState.user;
      final targetId = targetParticipant.identity;
      RoomMember? targetMember;
      try {
        targetMember = roomData.members.firstWhere((m) => m.uid == targetId);
      } catch (_) {}

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
              otherUserName:
                  targetMember?.displayName ?? targetParticipant.name,
              otherUserPhoto: targetMember?.avatarUrl,
            ),
          ),
        );
      } catch (e) {
        debugPrint("Error: $e");
      }
    }
  }

  void _confirmKick(BuildContext context) {
    showDialog(
      context: navigatorKey.currentContext!,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text("Kick User?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "This will remove them from the room.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              navigatorKey.currentContext!.read<RoomBloc>().add(
                KickUserEvent(
                  roomId: roomData.id,
                  userId: targetParticipant.identity!,
                ),
              );
            },
            child: const Text("Kick", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2C2C2C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              targetParticipant.name.isNotEmpty
                  ? targetParticipant.name
                  : "User",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: Colors.blueAccent,
              ),
              title: const Text(
                "Message Privately",
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                onClose();
                RoomGlobalManager().collapse();

                _initiatePrivateChat(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.fullscreen, color: Colors.grey),
              title: const Text(
                "View Full Screen",
                style: TextStyle(color: Colors.white),
              ),
              onTap: onSetFullScreen,
            ),
            if (amIHost) ...[
              const Divider(color: Colors.white24),
              ListTile(
                leading: const Icon(Icons.star_border, color: Colors.amber),
                title: Text(
                  currentSpotlightId == targetParticipant.identity
                      ? "Remove Spotlight"
                      : "Spotlight for Everyone",
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  onClose();
                  final isCurrentlySpotlighted =
                      currentSpotlightId == targetParticipant.identity;
                  navigatorKey.currentContext!.read<RoomBloc>().add(
                    ToggleSpotlightEvent(
                      roomId: roomData.id,
                      userId: isCurrentlySpotlighted
                          ? null
                          : targetParticipant.identity,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  "Kick User",
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  onClose();
                  _confirmKick(context);
                },
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
