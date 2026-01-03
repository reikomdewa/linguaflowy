import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/speak/room/room_bloc.dart';
import 'package:linguaflow/blocs/speak/room/room_event.dart';
import 'package:linguaflow/models/speak/speak_models.dart';

class BoardRequestsSheet extends StatelessWidget {
  final ChatRoom room;
  
  const BoardRequestsSheet({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    // Filter members who are in the requests list
    final requests = room.boardRequests ?? []; // Add boardRequests to ChatRoom model if not there
    // Map IDs to actual Member objects
    final requestMembers = room.members.where((m) => requests.contains(m.uid)).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Board Requests", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (requestMembers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text("No pending requests.", style: TextStyle(color: Colors.grey)),
            ),
          
          ...requestMembers.map((member) => ListTile(
            leading: CircleAvatar(backgroundImage: NetworkImage(member.avatarUrl ?? '')),
            title: Text(member.displayName!, style: const TextStyle(color: Colors.white)),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                context.read<RoomBloc>().add(GrantBoardAccessEvent(roomId: room.id, targetUserId: member.uid));
                Navigator.pop(context);
              },
              child: const Text("Accept"),
            ),
          )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}