import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:linguaflow/blocs/speak/speak_bloc.dart';
import 'package:linguaflow/blocs/speak/speak_event.dart';
import 'package:linguaflow/models/room_member.dart';
import 'package:linguaflow/models/speak_models.dart';
import 'package:linguaflow/screens/speak/widgets/active_room_screen.dart';
import 'package:linguaflow/services/speak/speak_service.dart';
import 'package:linguaflow/utils/language_helper.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:dotted_border/dotted_border.dart';

class RoomCard extends StatelessWidget {
  final ChatRoom room;

  const RoomCard({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 1. Sort members (Host first)
    final List<RoomMember> allMembers = List<RoomMember>.from(room.members);
    allMembers.sort((a, b) {
      if (a.uid == room.hostId) return -1;
      if (b.uid == room.hostId) return 1;
      return 0;
    });

    // 2. Logic for total items to display in the grid
    // If members > 10, we show exactly 10 items (9 avatars + 1 others bubble)
    // If members <= 10, we show avatars + placeholders up to maxMembers (capped at 10)
    int displayItemCount;
    bool showOthersBubble = room.memberCount > 10;

    if (showOthersBubble) {
      displayItemCount = 10;
    } else {
      // Show up to the limit of the room, but never more than 10 in this grid
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
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(LanguageHelper.getFlagEmoji(room.language), style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text("${room.language} (${room.level})", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                _buildMemberCounter(room),
              ],
            ),
            const SizedBox(height: 12),
            Text(room.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // --- GRID SECTION ---
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayItemCount,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.65, // Increased height to ensure no clipping
              ),
              itemBuilder: (context, index) {
                // RULE 1: If over 10 members, force slot 10 (index 9) to be the "Others" bubble
                if (showOthersBubble && index == 9) {
                  int remaining = room.memberCount - 9;
                  return _buildOthersIndicator(remaining, theme);
                }

                // RULE 2: Show actual members
                if (index < allMembers.length) {
                  return _buildMemberItem(allMembers[index], room.hostId);
                }

                // RULE 3: Show dashed placeholders ONLY for the empty slots within the room limit
                return _buildPlaceholder();
              },
            ),
            const SizedBox(height: 20),

            // Join Button
            _buildJoinButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCounter(ChatRoom room) {
    final bool isFull = room.memberCount >= room.maxMembers;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isFull ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.mic, size: 14, color: isFull ? Colors.red : Colors.blue),
          const SizedBox(width: 4),
          Text("${room.memberCount}/${room.maxMembers}", 
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isFull ? Colors.red : Colors.blue)),
        ],
      ),
    );
  }

  Widget _buildMemberItem(RoomMember member, String hostId) {
    final bool isHost = member.uid == hostId;
    return SizedBox(
      height: 80, // Fixed height container
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: isHost ? Colors.blue : Colors.transparent, width: 2),
            ),
            child: CircleAvatar(
              radius: 25,
              backgroundColor: Colors.blueGrey.shade800,
              backgroundImage: (member.avatarUrl != null && member.avatarUrl!.isNotEmpty)
                  ? NetworkImage(member.avatarUrl!) : null,
              child: (member.avatarUrl == null || member.avatarUrl!.isEmpty)
                  ? Text((member.displayName ?? "U")[0].toUpperCase(), 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.favorite, size: 10, color: Colors.blue),
              SizedBox(width: 2),
              Text("100", style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return SizedBox(
      height: 80,
      child: Column(
        children: [
          DottedBorder(
            options: RoundedRectDottedBorderOptions(
              color: Colors.grey.withOpacity(0.4),
              strokeWidth: 1,
              dashPattern: const [4, 4],
              radius: const Radius.circular(25),
            ),
            child: const SizedBox(width: 46, height: 46),
          ),
        ],
      ),
    );
  }

  Widget _buildOthersIndicator(int count, ThemeData theme) {
    return SizedBox(
      height: 80,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2), // High contrast
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blue.withOpacity(0.5), width: 1),
            ),
            alignment: Alignment.center,
            child: Text(
              "+$count\nothers",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold, height: 1.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinButton(BuildContext context) {
    return DottedBorder(
      options: RoundedRectDottedBorderOptions(
        color: const Color.fromRGBO(145, 155, 162, 1),
        strokeWidth: 1.2,
        dashPattern: const [6, 3],
        radius: const Radius.circular(12),
      ),
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: () => room.isPaid ? _showPaymentDialog(context) : _joinRoom(context, room),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.call_outlined, color: Color(0xFF2196F3), size: 20),
              SizedBox(width: 8),
              Text("Join and talk", style: TextStyle(color: Color(0xFF2196F3), fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  // Logic methods remain unchanged
  Future<void> _joinRoom(BuildContext context, ChatRoom roomData) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final token = await SpeakService().getLiveKitToken(roomData.id, FirebaseAuth.instance.currentUser?.displayName ?? "Guest");
      final livekitRoom = Room();
      await livekitRoom.connect('wss://linguaflow-7eemmnrq.livekit.cloud', token);
      if (context.mounted) {
        context.read<SpeakBloc>().add(RoomJoined(livekitRoom));
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => ActiveRoomScreen(roomData: roomData, livekitRoom: livekitRoom)));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _showPaymentDialog(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Join Paid Session"), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel"))]));
  }
}