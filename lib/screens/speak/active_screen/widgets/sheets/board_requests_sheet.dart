import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/speak/room/room_bloc.dart';
import 'package:linguaflow/blocs/speak/room/room_event.dart';
import 'package:linguaflow/models/speak/speak_models.dart';

class BoardRequestsSheet extends StatelessWidget {
  final ChatRoom room;
  final VoidCallback onClose; // New Callback
  
  const BoardRequestsSheet({
    super.key, 
    required this.room,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final requests = room.boardRequests ?? []; 
    final requestMembers = room.members.where((m) => requests.contains(m.uid)).toList();

    // Use Align to position it at the bottom like a bottom sheet
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Material(
          color: const Color(0xFF1E1E1E),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Board Requests", 
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: onClose, // Use callback
                    )
                  ],
                ),
                const SizedBox(height: 10),
                
                if (requestMembers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text("No pending requests.", style: TextStyle(color: Colors.grey)),
                  ),
                
                ...requestMembers.map((member) {
                  final hasAvatar = member.avatarUrl != null && member.avatarUrl!.isNotEmpty;
                  
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[800],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: hasAvatar 
                        ? Image.network(
                            member.avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white),
                          )
                        : const Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text(
                      member.displayName ?? "Unknown User", 
                      style: const TextStyle(color: Colors.white)
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        context.read<RoomBloc>().add(
                          GrantBoardAccessEvent(roomId: room.id, targetUserId: member.uid)
                        );
                        onClose(); // Close sheet after accepting
                      },
                      child: const Text("Accept"),
                    ),
                  );
                }),
                // Add bottom padding for safety
                SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}